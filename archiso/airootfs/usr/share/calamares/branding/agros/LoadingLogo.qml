/* The install page's loading animation: AgrOS's logo (its README banner, the name beside it in the logo's line), the
   three leaves drawn from the centre out, along the stem, round the tip and back, then gone the same way, and again
   (loopOf: 3 times as fast from the leaf's tip as it goes until it nears it drawing).
   Each line's moving ends come to a point, as the leaf's tips do; the finished leaf is the logo's own, its return line
   cut by the logo's gap (agros-logo.svg's mask). On a card with rounded corners (the slideshow's frame squared them).
   In the logo's colour, on Canvas (the installer draws Qt Quick in software here: pkexec-wrapper): one per leaf, so
   the gap cut out of one leaf leaves the others. The leaves' paths sampled as points (stem then the way back in full;
   leaves2.py made them) */
import QtQuick 2.15

Item {
    id: root

    // Where in the loop it is (ms, piecesAt)
    property real ms: 0

    readonly property color line: "#bec4ee"
    // Each leaf: its points (x, y, ...), and where the logo's paths start and end in them (stem, tip, return line)
    readonly property var leaves: [{"pts": [0.0, 0.0, -0.53, -0.61, -1.05, -1.23, -1.58, -1.85, -2.1, -2.49, -2.61, -3.14, -3.12, -3.8, -3.63, -4.47, -4.12, -5.14, -4.61, -5.82, -5.1, -6.51, -5.57, -7.21, -6.03, -7.91, -6.48, -8.61, -6.92, -9.32, -7.35, -10.04, -7.77, -10.76, -8.17, -11.48, -8.55, -12.2, -8.92, -12.93, -9.27, -13.66, -9.61, -14.39, -9.92, -15.11, -10.22, -15.84, -10.5, -16.57, -10.75, -17.29, -10.99, -18.02, -11.2, -18.74, -11.35, -19.4, -11.48, -20.07, -11.59, -20.74, -11.67, -21.41, -11.74, -22.08, -11.78, -22.75, -11.81, -23.43, -11.81, -24.11, -11.79, -24.79, -11.76, -25.47, -11.7, -26.15, -11.63, -26.84, -11.53, -27.53, -11.41, -28.22, -11.28, -28.91, -11.13, -29.6, -10.96, -30.3, -10.77, -30.99, -10.56, -31.69, -10.33, -32.39, -10.09, -33.09, -9.83, -33.8, -9.55, -34.5, -9.25, -35.21, -8.94, -35.92, -8.61, -36.63, -8.26, -37.34, -7.9, -38.05, -7.52, -38.77, -7.12, -39.48, -6.71, -40.2, -6.28, -40.92, -5.84, -41.64, -5.38, -42.37, -4.91, -43.09, -4.42, -43.82, -3.92, -44.54, -3.4, -45.27, -2.87, -46.0, -2.32, -46.73, -1.76, -47.46, -1.19, -48.2, -0.6, -48.93, -0.0, -49.67, 0.65, -49.24, 1.28, -48.79, 1.91, -48.32, 2.52, -47.83, 3.13, -47.33, 3.72, -46.82, 4.3, -46.28, 4.87, -45.74, 5.42, -45.18, 5.96, -44.6, 6.48, -44.02, 6.99, -43.42, 7.48, -42.81, 7.95, -42.19, 8.41, -41.56, 8.85, -40.91, 9.27, -40.26, 9.67, -39.6, 10.04, -38.93, 10.4, -38.25, 10.74, -37.57, 11.05, -36.87, 11.34, -36.17, 11.61, -35.47, 11.85, -34.76, 12.07, -34.04, 12.27, -33.32, 12.43, -32.6, 12.57, -31.87, 12.68, -31.14, 12.77, -30.41, 12.82, -29.68, 12.85, -28.94, 12.84, -28.21, 12.81, -27.47, 12.73, -26.83, 12.62, -26.2, 12.49, -25.55, 12.32, -24.9, 12.12, -24.24, 11.89, -23.57, 11.63, -22.89, 11.34, -22.2, 11.02, -21.5, 10.66, -20.78, 10.28, -20.04, 9.86, -19.29, 9.4, -18.51, 8.92, -17.72, 8.4, -16.91, 7.85, -16.07, 7.26, -15.21, 6.79, -14.52, 6.31, -13.84, 5.84, -13.15, 5.36, -12.47, 4.89, -11.78, 4.41, -11.1, 3.94, -10.41, 3.46, -9.73, 2.99, -9.04, 2.51, -8.36, 2.04, -7.67, 1.56, -6.99, 1.09, -6.3, 0.61, -5.62, 0.14, -4.93], "stemEnd": 71, "tipFrom": 27, "tipTo": 106}, {"pts": [-0.0, 0.0, 0.79, -0.15, 1.59, -0.3, 2.39, -0.44, 3.21, -0.57, 4.03, -0.69, 4.85, -0.8, 5.68, -0.91, 6.51, -1.0, 7.35, -1.09, 8.19, -1.16, 9.03, -1.22, 9.87, -1.27, 10.7, -1.31, 11.54, -1.34, 12.37, -1.35, 13.2, -1.35, 14.03, -1.33, 14.85, -1.3, 15.66, -1.26, 16.47, -1.2, 17.26, -1.13, 18.05, -1.04, 18.83, -0.93, 19.6, -0.81, 20.36, -0.67, 21.1, -0.51, 21.83, -0.33, 22.48, -0.13, 23.12, 0.09, 23.75, 0.33, 24.38, 0.59, 24.99, 0.87, 25.6, 1.17, 26.19, 1.49, 26.78, 1.83, 27.36, 2.18, 27.94, 2.55, 28.5, 2.94, 29.05, 3.35, 29.6, 3.78, 30.14, 4.22, 30.67, 4.69, 31.2, 5.17, 31.71, 5.66, 32.22, 6.17, 32.72, 6.7, 33.21, 7.25, 33.7, 7.81, 34.18, 8.39, 34.65, 8.99, 35.11, 9.6, 35.57, 10.22, 36.02, 10.86, 36.46, 11.52, 36.9, 12.19, 37.33, 12.88, 37.75, 13.58, 38.17, 14.29, 38.58, 15.02, 38.98, 15.77, 39.38, 16.53, 39.77, 17.3, 40.15, 18.08, 40.53, 18.88, 40.9, 19.69, 41.27, 20.52, 41.63, 21.35, 41.98, 22.2, 42.33, 23.07, 42.67, 23.94, 43.01, 24.83, 42.31, 25.17, 41.6, 25.5, 40.89, 25.81, 40.16, 26.1, 39.42, 26.37, 38.68, 26.63, 37.93, 26.87, 37.18, 27.08, 36.41, 27.28, 35.65, 27.46, 34.88, 27.62, 34.11, 27.76, 33.33, 27.88, 32.56, 27.98, 31.78, 28.06, 31.01, 28.12, 30.23, 28.16, 29.46, 28.17, 28.69, 28.17, 27.92, 28.14, 27.16, 28.08, 26.41, 28.01, 25.65, 27.91, 24.91, 27.79, 24.17, 27.65, 23.44, 27.48, 22.72, 27.28, 22.01, 27.07, 21.31, 26.82, 20.62, 26.56, 19.95, 26.26, 19.28, 25.94, 18.64, 25.6, 18.0, 25.23, 17.38, 24.83, 16.87, 24.44, 16.37, 24.03, 15.88, 23.59, 15.4, 23.12, 14.93, 22.62, 14.47, 22.08, 14.01, 21.52, 13.56, 20.92, 13.11, 20.29, 12.66, 19.62, 12.22, 18.92, 11.78, 18.18, 11.33, 17.4, 10.89, 16.58, 10.44, 15.73, 9.99, 14.83, 9.54, 13.89, 9.18, 13.14, 8.83, 12.38, 8.47, 11.63, 8.12, 10.88, 7.76, 10.12, 7.4, 9.37, 7.05, 8.62, 6.69, 7.86, 6.34, 7.11, 5.98, 6.36, 5.62, 5.6, 5.27, 4.85, 4.91, 4.1, 4.56, 3.34, 4.2, 2.59], "stemEnd": 71, "tipFrom": 27, "tipTo": 106}, {"pts": [0.0, 0.0, -0.26, 0.76, -0.53, 1.52, -0.82, 2.29, -1.11, 3.06, -1.42, 3.83, -1.73, 4.6, -2.06, 5.37, -2.39, 6.14, -2.74, 6.91, -3.09, 7.67, -3.46, 8.43, -3.83, 9.18, -4.22, 9.92, -4.61, 10.66, -5.02, 11.39, -5.43, 12.11, -5.86, 12.81, -6.29, 13.51, -6.74, 14.19, -7.19, 14.86, -7.66, 15.51, -8.13, 16.15, -8.61, 16.77, -9.1, 17.38, -9.6, 17.96, -10.11, 18.53, -10.63, 19.07, -11.13, 19.53, -11.64, 19.98, -12.17, 20.4, -12.7, 20.81, -13.25, 21.21, -13.81, 21.58, -14.39, 21.94, -14.97, 22.28, -15.57, 22.61, -16.18, 22.92, -16.8, 23.21, -17.43, 23.49, -18.07, 23.75, -18.73, 23.99, -19.39, 24.22, -20.07, 24.43, -20.76, 24.63, -21.45, 24.82, -22.16, 24.99, -22.88, 25.14, -23.61, 25.28, -24.35, 25.4, -25.1, 25.51, -25.86, 25.61, -26.63, 25.69, -27.41, 25.76, -28.2, 25.82, -29.0, 25.86, -29.81, 25.89, -30.63, 25.9, -31.46, 25.91, -32.3, 25.9, -33.14, 25.87, -34.0, 25.84, -34.86, 25.79, -35.73, 25.73, -36.61, 25.66, -37.5, 25.57, -38.4, 25.48, -39.31, 25.37, -40.22, 25.25, -41.14, 25.12, -42.07, 24.98, -43.01, 24.83, -42.96, 24.05, -42.89, 23.28, -42.79, 22.5, -42.68, 21.73, -42.55, 20.95, -42.4, 20.18, -42.23, 19.41, -42.04, 18.65, -41.83, 17.89, -41.61, 17.14, -41.36, 16.39, -41.1, 15.65, -40.81, 14.92, -40.51, 14.2, -40.19, 13.49, -39.86, 12.79, -39.5, 12.1, -39.13, 11.43, -38.74, 10.76, -38.33, 10.11, -37.9, 9.48, -37.46, 8.86, -37.0, 8.26, -36.52, 7.68, -36.03, 7.11, -35.52, 6.56, -34.99, 6.04, -34.45, 5.53, -33.89, 5.05, -33.31, 4.58, -32.72, 4.15, -32.12, 3.73, -31.49, 3.34, -30.85, 2.98, -30.2, 2.64, -29.61, 2.39, -29.0, 2.16, -28.38, 1.96, -27.73, 1.78, -27.06, 1.62, -26.36, 1.49, -25.64, 1.37, -24.9, 1.28, -24.13, 1.21, -23.33, 1.15, -22.49, 1.12, -21.63, 1.11, -20.74, 1.11, -19.81, 1.14, -18.84, 1.18, -17.84, 1.24, -16.8, 1.32, -15.97, 1.39, -15.14, 1.46, -14.31, 1.52, -13.48, 1.59, -12.65, 1.66, -11.82, 1.73, -10.99, 1.8, -10.15, 1.86, -9.32, 1.93, -8.49, 2.0, -7.66, 2.07, -6.83, 2.14, -6.0, 2.2, -5.17, 2.27, -4.34, 2.34], "stemEnd": 71, "tipFrom": 27, "tipTo": 106}]
    readonly property var stems: ["M0.00 0.00C-4.75 -5.41 -9.40 -12.26 -11.20 -18.74C-13.57 -28.46 -8.90 -38.86 -0.00 -49.67", "M-0.00 0.00C7.06 -1.41 15.32 -2.01 21.83 -0.33C31.43 2.48 38.10 11.73 43.01 24.83", "M0.00 0.00C-2.31 6.82 -5.92 14.27 -10.63 19.07C-17.86 25.98 -29.20 27.13 -43.01 24.83"]
    // The name, as in the banner (static)
    readonly property var name: [
        "M70.78 13.62L91.78 -36.38L112.78 13.62", "M79.18 -2.38H104.38",
        "M160.78 -4.38A18.0 18.0 0 1 1 124.78 -4.38A18.0 18.0 0 1 1 160.78 -4.38",
        "M160.78 -26.38V23.62A18.0 12.6 0 0 1 126.78 23.62", "M175.78 -26.38V13.62",
        "M175.78 -5.28C175.78 -20.38 184.78 -22.38 200.78 -22.38",
        "M265.78 -11.38A25.0 25.0 0 1 1 215.78 -11.38A25.0 25.0 0 1 1 265.78 -11.38",
        "M313.78 -29.51C307.78 -36.38 279.78 -36.38 279.78 -23.88C279.78 -11.38 313.78 -11.38 313.78 1.12C313.78 13.62 283.78 13.62 277.78 6.74"
    ]

    onMsChanged: leafCanvases.paint()

    // One leaf, on its own layer (ctx): its pieces, each [head, tail] (0-1 along it; more than one while the next
    // drawing starts at the centre as the last one leaves). The parts as the logo draws them: the return line, then the
    // logo's gap cut out of it (its stems 18 wide, erased), then the stem and the mitred tip over it
    function drawLeaf(ctx, leaf, pieces, stems, strokeSvg) {
        const pts = leaf.pts, n = pts.length / 2, W = 8, P = 9; // line width; how long it grows thin, in points (0.8 apart)
        // a point at index i (fractional; past the ends, on along the end's direction)
        const at = i => {
            const k = Math.max(0, Math.min(n - 2, Math.floor(i))), f = i - k;
            return [pts[k * 2] + (pts[k * 2 + 2] - pts[k * 2]) * f, pts[k * 2 + 1] + (pts[k * 2 + 3] - pts[k * 2 + 1]) * f];
        };
        const normal = i => {
            const a = at(i - 0.5), b = at(i + 0.5), l = Math.hypot(b[0] - a[0], b[1] - a[1]) || 1;
            return [-(b[1] - a[1]) / l, (b[0] - a[0]) / l];
        };
        // The moving ends cut on the slant of the logo's own ends (where its gap cuts the return line: the edge on the
        // leaf's inside 1.6 longer, over the line's 8): the drawing end so, the erasing end the mirror of it, its face
        // turned to the leaf's inside. While a piece is short it's thinner too, so it grows out of a point
        const shown = [];
        for (const [head, tail] of pieces) {
            const h = head * (n - 1 + P), t = tail * (n - 1 + P) - P;
            if (h <= Math.max(t, 0))
                continue;
            const len = h - Math.max(t, 0), w = W * Math.min(1, len / (2 * P)), d = 2 * w / W; // (d: the slant, in points)
            shown.push({ h, t, w, d, headBase: h - d / 2, tailBase: t > 0 ? t + d / 2 : 0 });
        }
        // the cut's corner: from the line's end (base) its edge on one side (side: +1 the leaf's inside) runs on to tip
        function nib(p, base, tip, side) {
            const back = tip > base ? -0.6 : 0.6; // (from a little inside the line: no seam where they meet)
            const c = at(base + back), nr = normal(base), e = at(tip), ne = normal(tip);
            ctx.beginPath();
            ctx.moveTo(c[0] + nr[0] * side * p.w / 2, c[1] + nr[1] * side * p.w / 2);
            ctx.lineTo(e[0] + ne[0] * side * p.w / 2, e[1] + ne[1] * side * p.w / 2);
            ctx.lineTo(c[0] - nr[0] * side * p.w / 2, c[1] - nr[1] * side * p.w / 2);
            ctx.closePath();
            ctx.fill();
        }
        // each piece within the logo path lo..hi: a line, and its cut where a moving end falls in it
        function part(lo, hi) {
            for (const p of shown) {
                const a = Math.max(lo, p.tailBase), b = Math.min(hi, p.headBase);
                if (b > a) {
                    ctx.lineWidth = p.w;
                    ctx.beginPath();
                    const s = at(a);
                    ctx.moveTo(s[0], s[1]);
                    for (let i = Math.floor(a) + 1; i < b; i++)
                        ctx.lineTo(pts[i * 2], pts[i * 2 + 1]);
                    const e = at(b);
                    ctx.lineTo(e[0], e[1]);
                    ctx.stroke();
                }
                if (p.headBase >= lo - 0.01 && p.headBase <= hi)
                    nib(p, p.headBase, p.h + p.d / 2, 1);
                if (p.t > 0 && p.tailBase >= lo && p.tailBase <= hi + 0.01)
                    nib(p, p.tailBase, p.t - p.d / 2, -1);
            }
        }
        if (!shown.length)
            return;
        part(leaf.stemEnd, n - 1 + P); // (past its end: the gap cuts it there anyway)
        ctx.globalCompositeOperation = "destination-out";
        ctx.lineWidth = 18;
        for (const s of stems)
            strokeSvg(ctx, s);
        ctx.globalCompositeOperation = "source-over";
        part(0, leaf.stemEnd);
        part(leaf.tipFrom, leaf.tipTo);
    }

    // The loop: shown (0.7 s), gone, 0.13 s empty, drawn again, at one speed along the line that changes at the leaf's tip. Going
    // starts at the normal speed (the whole line in 0.8 s) and, from early on the stem, gradually speeds up to 3 times it by the tip, for the
    // rest of the going and the drawing that follows; the drawing, from early on the stem, gradually slows back to the normal
    // speed for the rest. Times by stepping along the line (half a point a step)
    function loopOf(leaf) {
        const n = leaf.pts.length / 2, P = 9, L = n - 1 + P, tip = leaf.stemEnd, R = 45; // (P: drawLeaf's; R: the ramp, most of the stem)
        const v0 = L / 800, H = 700, step = 0.5, times = [0];
        const ramp = x => { const c = Math.max(0, Math.min(1, x)); return c * c * (3 - 2 * c); };
        // u: 0-L the going (its tail at u - P), L-2L the drawing (its head at u - L)
        const speed = u => u < L ? v0 * (1 + 2 * ramp((u - P - (tip - R)) / R)) : v0 * (3 - 2 * ramp((u - L - (tip + 15)) / R)); // (the drawing slows from 15 points past the tip to 60 past it, near the end)
        for (let u = 0; u < 2 * L; u += step)
            times.push(times[times.length - 1] + step / speed(u + step / 2));
        const gap = 130, gone = times[Math.round(L / step)]; // (gap: the empty card between going and drawing)
        return { L, H, step, times, gap, gone, C: H + times[times.length - 1] + gap };
    }
    function piecesAt(ms, leaf) {
        const o = loopOf(leaf);
        let t = ((ms % o.C) + o.C) % o.C - o.H;
        if (t < 0)
            return [[1, 0]];
        if (t >= o.gone && t < o.gone + o.gap)
            return [];
        if (t >= o.gone)
            t -= o.gap;
        let k = 1;
        while (k < o.times.length - 1 && o.times[k] < t)
            k++;
        const u = Math.min(2 * o.L, (k - 1 + (t - o.times[k - 1]) / (o.times[k] - o.times[k - 1])) * o.step);
        return u < o.L ? [[1, u / o.L]] : [[(u - o.L) / o.L, 0]];
    }

    // The banner's box (its SVG's viewBox), fitted in the card with room round it; the same for every layer
    function place(ctx, width, height) {
        const vbX = -50, vbY = -61.77, vbW = 371.78, vbH = 100.78;
        const k = Math.min(width * 0.6 / vbW, height * 0.45 / vbH);
        ctx.translate(width / 2 - (vbX + vbW / 2) * k, height / 2 - (vbY + vbH / 2) * k);
        ctx.scale(k, k);
        ctx.strokeStyle = root.line;
        ctx.fillStyle = root.line;
        ctx.lineWidth = 8;
        ctx.lineCap = "butt";
        ctx.lineJoin = "miter";
        ctx.miterLimit = 10;
    }

    // (one loop: loopOf's length, about 2.9 s)
    readonly property real loopMs: loopOf(leaves[0]).C
    NumberAnimation on ms {
        running: root.visible
        loops: Animation.Infinite
        from: 0
        to: root.loopMs
        duration: root.loopMs
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 18
        color: "#181920"
        border.color: "#24252e"
        border.width: 1
    }

    // The name (still)
    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            root.place(ctx, width, height);
            for (const p of root.name) {
                ctx.beginPath();
                ctx.path = p;
                ctx.stroke();
            }
        }
    }

    Item {
        id: leafCanvases

        function paint(): void {
            for (let i = 0; i < leafRepeater.count; i++)
                leafRepeater.itemAt(i).requestPaint();
        }

        anchors.fill: parent

        Repeater {
            id: leafRepeater

            model: 3

            Canvas {
                required property int index

                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    root.place(ctx, width, height);
                    root.drawLeaf(ctx, root.leaves[index], root.piecesAt(root.ms, root.leaves[index]), root.stems, (c, s) => {
                        c.beginPath();
                        c.path = s;
                        c.stroke();
                    });
                }
            }
        }
    }
}
