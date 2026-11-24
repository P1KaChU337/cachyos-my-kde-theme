/*
    Smooth Maximize — локальная переделка стандартного эффекта KWin "maximize".
    Основано на коде Martin Gräßlin (GPL-2.0-or-later).

    Отличия от оригинала:
      * дольше и мягче (OutQuint);
      * если приложение меняет размер по ходу анимации (Firefox, Electron),
        анимация подхватывается с текущего видимого положения и плавно доводится
        до нового размера, а не обрывается/не уезжает;
      * при перетаскивании/растягивании окна мышью эффект не вмешивается.
*/

"use strict";

function easeOutQuint(t) {
    return 1 - Math.pow(1 - t, 5);
}

function rect(g) {
    return { x: g.x, y: g.y, width: g.width, height: g.height };
}

class SmoothMaximizeEffect {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effect.animationEnded.connect(this.onAnimationEnded.bind(this));

        effects.windowAdded.connect(this.manage.bind(this));
        for (const window of effects.stackingOrder) {
            window.setData(Effect.WindowForceBlurRole, null);
            this.manage(window);
        }
        this.loadConfig();
    }

    loadConfig() {
        this.duration = animationTime(340);
    }

    manage(window) {
        window.windowFrameGeometryChanged.connect(this.onGeometryChanged.bind(this));
        window.windowMaximizedStateChanged.connect(this.onMaximizedStateChanged.bind(this));
        window.windowMaximizedStateAboutToChange.connect(this.onAboutToChange.bind(this));
    }

    userInteracting(window) {
        return window.move || window.resize;
    }

    // где окно визуально находится прямо сейчас (если идёт наша анимация)
    visualRect(window) {
        const a = window.smAnim;
        if (!a) return null;
        const t = (Date.now() - a.start) / a.duration;
        if (t >= 1) return null;
        const e = easeOutQuint(Math.max(0, t));
        const lerp = (k) => a.from[k] + (a.to[k] - a.from[k]) * e;
        return { x: lerp("x"), y: lerp("y"), width: lerp("width"), height: lerp("height"),
                 remaining: a.duration * (1 - t) };
    }

    track(window, ids) {
        if (!window.smIds) window.smIds = [];
        for (const id of (Array.isArray(ids) ? ids : [ids])) {
            if (window.smIds.indexOf(id) === -1) window.smIds.push(id);
        }
    }

    untrack(window, ids) {
        if (!window.smIds) return;
        for (const id of (Array.isArray(ids) ? ids : [ids])) {
            const i = window.smIds.indexOf(id);
            if (i !== -1) window.smIds.splice(i, 1);
        }
        this.maybeFinish(window);
    }

    // когда ни одной нашей анимации не осталось — обязательно снимаем размытие
    maybeFinish(window) {
        if (window.smIds && window.smIds.length > 0) return;
        delete window.smMorph;
        delete window.smFade;
        delete window.smAnim;
        window.setData(Effect.WindowForceBlurRole, null);
    }

    stopMorph(window) {
        if (window.smMorph) {
            cancel(window.smMorph);
            const ids = window.smMorph;
            delete window.smMorph;
            delete window.smAnim;
            this.untrack(window, ids);
        }
        delete window.smAnim;
    }

    startMorph(window, from, to, duration) {
        this.stopMorph(window);
        window.smAnim = { start: Date.now(), duration: duration, from: rect(from), to: rect(to) };
        window.smMorph = animate({
            window: window,
            duration: duration,
            animations: [{
                type: Effect.Size,
                from: { value1: from.width, value2: from.height },
                to: { value1: to.width, value2: to.height },
                curve: QEasingCurve.OutQuint
            }, {
                type: Effect.Translation,
                from: {
                    value1: from.x - to.x - (to.width / 2 - from.width / 2),
                    value2: from.y - to.y - (to.height / 2 - from.height / 2)
                },
                to: { value1: 0, value2: 0 },
                curve: QEasingCurve.OutQuint
            }]
        });
        this.track(window, window.smMorph);
    }

    onAboutToChange(window) {
        if (!window.visible || this.userInteracting(window)) {
            delete window.smOld;
            return;
        }
        // стартуем с текущего видимого положения, если предыдущая анимация ещё идёт
        window.smOld = this.visualRect(window) || rect(window.geometry);

        let retargeted = false;
        if (window.smFade) {
            retargeted = retarget(window.smFade, 1.0, this.duration);
        }
        if (!retargeted) {
            window.smFade = animate({
                window: window,
                duration: this.duration,
                animations: [{
                    type: Effect.CrossFadePrevious,
                    from: 0.0,
                    to: 1.0,
                    curve: QEasingCurve.OutQuint
                }]
            });
            this.track(window, window.smFade);
        }
    }

    onMaximizedStateChanged(window) {
        if (!window.visible || !window.smOld) {
            return;
        }
        const from = window.smOld;
        delete window.smOld;
        if (this.userInteracting(window)) {
            if (window.smFade) { cancel(window.smFade); this.untrack(window, window.smFade); }
            return;
        }
        window.setData(Effect.WindowForceBlurRole, true);
        this.startMorph(window, from, window.geometry, this.duration);
        if (window.smFade) {
            retarget(window.smFade, 1.0, this.duration);
        }
    }

    onGeometryChanged(window, oldGeometry) {
        if (!window.smAnim) {
            return;
        }
        const g = window.geometry;
        if (g.width === oldGeometry.width && g.height === oldGeometry.height &&
            g.x === oldGeometry.x && g.y === oldGeometry.y) {
            return;
        }
        if (this.userInteracting(window)) {
            this.stopMorph(window);
            return;
        }
        const vis = this.visualRect(window);
        if (!vis) {
            delete window.smAnim;
            return;
        }
        // приложение доресайзилось по ходу — плавно доводим до нового размера
        const remaining = Math.max(vis.remaining, animationTime(140));
        this.startMorph(window, vis, g, remaining);
        if (window.smFade) {
            retarget(window.smFade, 1.0, remaining);
        }
    }

    onAnimationEnded(window, animationId) {
        this.untrack(window, animationId);
    }
}

new SmoothMaximizeEffect();
