"use strict";
// Масштабирование всплывающих окон панелей (меню приложений, трей, календарь и т.п.)
// от центра той стороны, где находится панель.

const START_SCALE = 0.86;
const END_SCALE = 0.93;

// обычные всплывашки (контекстные меню, подсказки) — простое затухание, как в стандартном Fading Popups,
// который выключен, чтобы он не дрался с этим эффектом за меню панели
const FADE_BLACKLIST = ["ksmserver ksmserver", "ksmserver-logout-greeter ksmserver-logout-greeter", "ksplashqml ksplashqml"];
function isPlainPopup(w) {
    if (w.appletPopup) return false;
    if (FADE_BLACKLIST.indexOf(w.windowClass) !== -1) return false;
    if (w.popupWindow || w.outline) return true;
    if (!w.managed) return !w.utility;
    return !!(w.splash || w.toolbar || w.onScreenDisplay);
}

class PopupZoom {
    constructor() {
        effect.configChanged.connect(this.loadConfig.bind(this));
        effects.windowAdded.connect(this.added.bind(this));
        effects.windowClosed.connect(this.closed.bind(this));
        this.loadConfig();
    }

    loadConfig() {
        this.inDuration = animationTime(260);
        this.outDuration = animationTime(170);
        this.fadeIn = animationTime(150);
        this.fadeOut = animationTime(150) * 4;
    }

    // KWin's blur/contrast skip transformed (scaled/translated) windows unless forced,
    // so without this the glass background pops in only after the animation ends
    forceGlass(w, on) {
        w.setData(Effect.WindowForceBlurRole, on ? true : null);
        w.setData(Effect.WindowForceBackgroundContrastRole, on ? true : null);
    }

    // Blur/contrast normally skip transformed windows. For panel popups and KRunner we just
    // keep them forced for the window's whole life: when the window is not being animated
    // this changes nothing, and during any animation (our zoom or KWin's Sliding Popups)
    // the glass stays. (A timer via a no-op animation kept closed windows alive -> double close.)
    isGlassWindow(w) {
        return w.appletPopup || String(w.windowClass).indexOf("krunner") !== -1;
    }

    // смещение, при котором край со стороны панели остаётся на месте
    anchorOffset(w, s) {
        const scr = effects.virtualScreenGeometry;
        const g = w.geometry;
        const centerY = g.y + g.height / 2;
        const dy = g.height * (1 - s) / 2;
        // меню у верхней панели — якорь сверху, у дока — снизу
        return { x: 0, y: centerY < scr.y + scr.height / 2 ? -dy : dy };
    }

    added(w) {
        if (effects.hasActiveFullScreenEffect || !w.visible) return;
        if (this.isGlassWindow(w)) this.forceGlass(w, true);
        if (isPlainPopup(w)) {
            if (effect.grab(w, Effect.WindowAddedGrabRole))
                animate({ window: w, curve: QEasingCurve.Linear, duration: this.fadeIn, type: Effect.Opacity, from: 0, to: 1 });
            return;
        }
        if (!w.appletPopup) return;
        if (!effect.grab(w, Effect.WindowAddedGrabRole, true)) return;
        const off = this.anchorOffset(w, START_SCALE);
        w.pzIn = animate({
            window: w,
            duration: this.inDuration,
            curve: QEasingCurve.OutCubic,
            animations: [
                { type: Effect.Scale, from: { value1: START_SCALE, value2: START_SCALE }, to: { value1: 1, value2: 1 } },
                { type: Effect.Translation, from: { value1: off.x, value2: off.y }, to: { value1: 0, value2: 0 } },
                { type: Effect.Opacity, from: 0, to: 1, curve: QEasingCurve.OutQuad }
            ]
        });
    }

    closed(w) {
        if (effects.hasActiveFullScreenEffect || !w.visible || w.skipsCloseAnimation) return;
        if (isPlainPopup(w)) {
            if (effect.grab(w, Effect.WindowClosedGrabRole))
                animate({ window: w, curve: QEasingCurve.OutQuart, duration: this.fadeOut, type: Effect.Opacity, from: 1, to: 0 });
            return;
        }
        if (!w.appletPopup) return;
        if (!effect.grab(w, Effect.WindowClosedGrabRole, true)) return;
        if (w.pzIn) { cancel(w.pzIn); delete w.pzIn; }
        const off = this.anchorOffset(w, END_SCALE);
        animate({
            window: w,
            duration: this.outDuration,
            curve: QEasingCurve.InCubic,
            animations: [
                { type: Effect.Scale, from: { value1: 1, value2: 1 }, to: { value1: END_SCALE, value2: END_SCALE } },
                { type: Effect.Translation, from: { value1: 0, value2: 0 }, to: { value1: off.x, value2: off.y } },
                { type: Effect.Opacity, from: 1, to: 0 }
            ]
        });
    }
}

new PopupZoom();
