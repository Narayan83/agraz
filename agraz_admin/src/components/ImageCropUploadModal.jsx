import React, { useEffect, useMemo, useRef, useState } from "react";
import { Crop, Upload, RotateCcw } from "lucide-react";
import { uploadAdminEcomImage } from "../api/api";

import "./ImageCropUploadModal.css";

const clamp = (v, min, max) => Math.min(max, Math.max(min, v));

// Square 1:1 crop. Frontend crops into a new blob and uploads it.
const ImageCropUploadModal = ({
  open,
  file,
  kind,
  onClose,
  onUploaded,
}) => {
  const shellRef = useRef(null);
  const [boxSize, setBoxSize] = useState(420);

  const objectUrl = useMemo(() => {
    if (!file) return null;
    return URL.createObjectURL(file);
  }, [file]);

  const imgRef = useRef(null);
  const [natural, setNatural] = useState(null);
  const [scale, setScale] = useState(1.2);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [cropSize, setCropSize] = useState(420);
  const dragRef = useRef(null);
  const resizeRef = useRef(null);
  const frameRef = useRef(null);

  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    setError("");
    setBusy(false);
    setScale(1.2);
    setOffset({ x: 0, y: 0 });
  }, [open, file]);

  useEffect(() => {
    if (!open || !objectUrl) return;
    const id = requestAnimationFrame(() => {
      const w = frameRef.current?.clientWidth;
      if (w) setCropSize(w);
    });
    return () => cancelAnimationFrame(id);
  }, [open, objectUrl]);

  useEffect(() => {
    if (!open) return;
    setCropSize((c) => Math.min(c, boxSize));
  }, [boxSize, open]);

  useEffect(() => {
    if (!open || !shellRef.current) return;
    const el = shellRef.current;
    const gap = 20;
    /* Loosely matches flex basis of `.ecom-crop-controls` (must stay ≤ available width when stacked). */
    const controlsCol = 280;

    const compute = () => {
      const r = el.getBoundingClientRect();
      if (r.width < 8 || r.height < 8) return;
      const sideBySide = r.width >= controlsCol + gap + 280;
      const vCap = Math.max(260, window.innerHeight - 180);
      let side;
      if (sideBySide) {
        const forPreview = r.width - controlsCol - gap;
        side = Math.min(560, forPreview, vCap);
      } else {
        side = Math.min(560, r.width - 24, vCap);
      }
      setBoxSize(Math.floor(Math.max(240, side)));
    };

    const ro = new ResizeObserver(() => compute());
    ro.observe(el);
    window.addEventListener("resize", compute);
    const mo = new MutationObserver(() => {
      requestAnimationFrame(compute);
    });
    mo.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-admin-sidebar"],
    });
    compute();
    return () => {
      ro.disconnect();
      window.removeEventListener("resize", compute);
      mo.disconnect();
    };
  }, [open]);

  useEffect(() => {
    if (!objectUrl) return;

    const img = new Image();
    imgRef.current = img;
    img.onload = () => {
      setNatural({ width: img.naturalWidth, height: img.naturalHeight });
    };
    img.onerror = () => setError("Failed to load image for cropping.");
    img.src = objectUrl;
    return () => {
      try {
        URL.revokeObjectURL(objectUrl);
      } catch (e) {
        void e;
      }
    };
  }, [objectUrl]);

  const baseScale = useMemo(() => {
    if (!natural) return 1;
    // "cover" fit into the crop square.
    return Math.max(boxSize / natural.width, boxSize / natural.height);
  }, [natural, boxSize]);

  const display = useMemo(() => {
    if (!natural) return { w: boxSize, h: boxSize };
    const s = baseScale * scale;
    return { w: natural.width * s, h: natural.height * s };
  }, [natural, baseScale, scale, boxSize]);

  const imageOrigin = useMemo(() => {
    // Top-left of the scaled image inside the crop square.
    const left = (boxSize - display.w) / 2 + offset.x;
    const top = (boxSize - display.h) / 2 + offset.y;
    return { left, top };
  }, [boxSize, display, offset]);

  const panBounds = useMemo(() => {
    if (!natural) return { maxX: 0, maxY: 0 };
    return {
      maxX: Math.max(0, (display.w - boxSize) / 2),
      maxY: Math.max(0, (display.h - boxSize) / 2),
    };
  }, [natural, display.w, display.h, boxSize]);

  const clampOffset = (nextOffset) => ({
    x: clamp(nextOffset.x, -panBounds.maxX, panBounds.maxX),
    y: clamp(nextOffset.y, -panBounds.maxY, panBounds.maxY),
  });

  useEffect(() => {
    if (!natural) return;
    const { maxX, maxY } = panBounds;
    setOffset((prev) => {
      const next = {
        x: clamp(prev.x, -maxX, maxX),
        y: clamp(prev.y, -maxY, maxY),
      };
      if (prev.x === next.x && prev.y === next.y) return prev;
      return next;
    });
  }, [natural, panBounds]);

  const onPointerDown = (e) => {
    if (!natural) return;
    if (e.button !== undefined && e.button !== 0) return;
    const target = e.currentTarget;
    target.setPointerCapture?.(e.pointerId);
    dragRef.current = {
      startX: e.clientX,
      startY: e.clientY,
      startOffset: offset,
    };
  };

  const onPointerMove = (e) => {
    if (resizeRef.current) return;
    const d = dragRef.current;
    if (!d || !natural) return;
    const dx = e.clientX - d.startX;
    const dy = e.clientY - d.startY;
    const next = clampOffset({ x: d.startOffset.x + dx, y: d.startOffset.y + dy });
    setOffset(next);
  };

  const onPointerUp = () => {
    dragRef.current = null;
  };

  const minCrop = Math.max(48, Math.floor(boxSize * 0.12));

  const onCornerPointerDown = (corner) => (e) => {
    if (!natural) return;
    if (e.button !== undefined && e.button !== 0) return;
    e.stopPropagation();
    resizeRef.current = { corner };
    e.currentTarget.setPointerCapture?.(e.pointerId);
  };

  const onCornerPointerMove = (e) => {
    const r = resizeRef.current;
    const fr = frameRef.current;
    if (!r?.corner || !fr) return;
    const bounds = fr.getBoundingClientRect();
    const x = e.clientX - bounds.left;
    const y = e.clientY - bounds.top;
    const cx = boxSize / 2;
    const cy = boxSize / 2;
    let half = 0;
    switch (r.corner) {
      case "br":
        half = Math.min(x - cx, y - cy);
        break;
      case "bl":
        half = Math.min(cx - x, y - cy);
        break;
      case "tr":
        half = Math.min(x - cx, cy - y);
        break;
      case "tl":
        half = Math.min(cx - x, cy - y);
        break;
      default:
        return;
    }
    const minHalf = minCrop / 2;
    const maxHalf = boxSize / 2;
    setCropSize(Math.round(clamp(half, minHalf, maxHalf) * 2));
  };

  const onCornerPointerUp = (e) => {
    resizeRef.current = null;
    try {
      e.currentTarget.releasePointerCapture?.(e.pointerId);
    } catch {
      /* ignore */
    }
  };

  const outputSize = 1000; // square output size in pixels

  const cropAndUpload = async () => {
    if (!imgRef.current || !natural) return;
    setError("");
    setBusy(true);
    try {
      const canvas = document.createElement("canvas");
      canvas.width = outputSize;
      canvas.height = outputSize;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("Canvas not supported");

      const s = baseScale * scale;
      const minC = Math.max(48, Math.floor(boxSize * 0.12));
      const cropPx = clamp(cropSize, minC, boxSize);
      const inset = (boxSize - cropPx) / 2;
      const srcX = (inset - imageOrigin.left) / s;
      const srcY = (inset - imageOrigin.top) / s;
      const srcSize = cropPx / s;

      const sx = clamp(srcX, 0, Math.max(0, natural.width - srcSize));
      const sy = clamp(srcY, 0, Math.max(0, natural.height - srcSize));
      const sw = srcSize;
      const sh = srcSize;

      // Draw crop square from the original image.
      ctx.imageSmoothingEnabled = true;
      ctx.drawImage(imgRef.current, sx, sy, sw, sh, 0, 0, outputSize, outputSize);

      const blob = await new Promise((resolve, reject) => {
        canvas.toBlob((b) => {
          if (!b) return reject(new Error("Failed to create cropped image."));
          resolve(b);
        }, "image/jpeg", 0.92);
      });

      const uploadRes = await uploadAdminEcomImage({
        kind,
        file: new File([blob], "cropped.jpg", { type: blob.type || "image/jpeg" }),
      });

      onUploaded(uploadRes?.url);
    } catch (err) {
      setError(err?.message || "Upload failed.");
    } finally {
      setBusy(false);
    }
  };

  if (!open) return null;

  const kindLabel =
    kind === "variant" ? "Variant" : kind === "hero" ? "Hero banner" : "Product";

  const crop = clamp(cropSize, minCrop, boxSize);
  const m = (boxSize - crop) / 2;
  const hz = 14;
  const shade = "rgba(0, 0, 0, 0.48)";
  const handleBase = {
    position: "absolute",
    width: 28,
    height: 28,
    zIndex: 4,
    touchAction: "none",
    boxSizing: "border-box",
    background: "rgba(255, 255, 255, 0.95)",
    border: "2px solid rgba(37, 99, 235, 0.95)",
    borderRadius: 4,
  };

  return (
    <div className="ecom-modal-overlay" onClick={onClose}>
      <div className="ecom-modal-content ecom-crop-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Crop {kindLabel} Image</h3>
          <button type="button" className="close-btn" onClick={onClose}>
            ✕
          </button>
        </div>

        <div className="ecom-modal-body">
          <div className="ecom-crop-shell" ref={shellRef}>
            <div
              className="ecom-crop-frame"
              ref={frameRef}
              style={{ width: boxSize, height: boxSize }}
            >
              {objectUrl && (
                <img
                  src={objectUrl}
                  alt="to crop"
                  className="ecom-crop-image"
                  draggable={false}
                  style={{
                    width: display.w,
                    height: display.h,
                    transform: `translate(${imageOrigin.left}px, ${imageOrigin.top}px)`,
                  }}
                />
              )}
              <div
                className="ecom-crop-overlay"
                onPointerDown={onPointerDown}
                onPointerMove={onPointerMove}
                onPointerUp={onPointerUp}
                onPointerCancel={onPointerUp}
              />
              <div className="ecom-crop-shades" aria-hidden="true">
                <div className="ecom-crop-shade" style={{ left: 0, right: 0, top: 0, height: m, background: shade }} />
                <div
                  className="ecom-crop-shade"
                  style={{ left: 0, right: 0, top: m + crop, bottom: 0, background: shade }}
                />
                <div
                  className="ecom-crop-shade"
                  style={{ left: 0, top: m, width: m, height: crop, background: shade }}
                />
                <div
                  className="ecom-crop-shade"
                  style={{ left: m + crop, right: 0, top: m, height: crop, background: shade }}
                />
              </div>
              <div className="ecom-crop-hud" aria-hidden="true">
                <div
                  className="ecom-crop-edge ecom-crop-edge--top"
                  style={{ left: m, top: m, width: crop, height: 3 }}
                />
                <div
                  className="ecom-crop-edge ecom-crop-edge--bottom"
                  style={{ left: m, top: m + crop - 3, width: crop, height: 3 }}
                />
                <div
                  className="ecom-crop-edge ecom-crop-edge--left"
                  style={{ left: m, top: m, width: 3, height: crop }}
                />
                <div
                  className="ecom-crop-edge ecom-crop-edge--right"
                  style={{ left: m + crop - 3, top: m, width: 3, height: crop }}
                />
                <span className="ecom-crop-corner ecom-crop-corner--tl" style={{ left: m, top: m }} />
                <span className="ecom-crop-corner ecom-crop-corner--tr" style={{ left: m + crop - 26, top: m }} />
                <span className="ecom-crop-corner ecom-crop-corner--bl" style={{ left: m, top: m + crop - 26 }} />
                <span
                  className="ecom-crop-corner ecom-crop-corner--br"
                  style={{ left: m + crop - 26, top: m + crop - 26 }}
                />
              </div>
              <button
                type="button"
                aria-label="Resize crop from top-left"
                className="ecom-crop-handle ecom-crop-handle--tl"
                style={{ ...handleBase, left: m - hz, top: m - hz, cursor: "nwse-resize" }}
                onPointerDown={onCornerPointerDown("tl")}
                onPointerMove={onCornerPointerMove}
                onPointerUp={onCornerPointerUp}
                onPointerCancel={onCornerPointerUp}
              />
              <button
                type="button"
                aria-label="Resize crop from top-right"
                className="ecom-crop-handle ecom-crop-handle--tr"
                style={{ ...handleBase, left: m + crop - hz, top: m - hz, cursor: "nesw-resize" }}
                onPointerDown={onCornerPointerDown("tr")}
                onPointerMove={onCornerPointerMove}
                onPointerUp={onCornerPointerUp}
                onPointerCancel={onCornerPointerUp}
              />
              <button
                type="button"
                aria-label="Resize crop from bottom-left"
                className="ecom-crop-handle ecom-crop-handle--bl"
                style={{ ...handleBase, left: m - hz, top: m + crop - hz, cursor: "nesw-resize" }}
                onPointerDown={onCornerPointerDown("bl")}
                onPointerMove={onCornerPointerMove}
                onPointerUp={onCornerPointerUp}
                onPointerCancel={onCornerPointerUp}
              />
              <button
                type="button"
                aria-label="Resize crop from bottom-right"
                className="ecom-crop-handle ecom-crop-handle--br"
                style={{ ...handleBase, left: m + crop - hz, top: m + crop - hz, cursor: "nwse-resize" }}
                onPointerDown={onCornerPointerDown("br")}
                onPointerMove={onCornerPointerMove}
                onPointerUp={onCornerPointerUp}
                onPointerCancel={onCornerPointerUp}
              />
            </div>

            <div className="ecom-crop-controls">
              <div className="ecom-slider-row">
                <label>Zoom</label>
                <input
                  type="range"
                  min={1}
                  max={3}
                  step={0.01}
                  value={scale}
                  onChange={(e) => setScale(Number(e.target.value))}
                />
                <span className="ecom-crop-zoom-val">{scale.toFixed(2)}x</span>
              </div>
              <button
                type="button"
                className="secondary-btn"
                onClick={() => {
                  setScale(1.2);
                  setOffset({ x: 0, y: 0 });
                  setCropSize(frameRef.current?.clientWidth ?? boxSize);
                }}
                disabled={busy}
              >
                <RotateCcw size={16} /> Reset
              </button>

              {error ? <div className="ecom-crop-error">{error}</div> : null}

              <button
                type="button"
                className="primary-btn"
                onClick={cropAndUpload}
                disabled={busy || !natural}
              >
                {busy ? (
                  <span className="ecom-inline-busy">
                    <LoaderSpin />
                    Uploading…
                  </span>
                ) : (
                  <span className="ecom-inline-busy">
                    <Crop size={18} />
                    <Upload size={18} />
                    Crop & Upload
                  </span>
                )}
              </button>
            </div>
          </div>
          <p className="ecom-note">
            Drag the image to reposition. Drag any blue corner handle to shrink or enlarge the square crop.
            Zoom if panning feels stuck. Output is a 1:1 square.
          </p>
        </div>
      </div>
    </div>
  );
};

const LoaderSpin = () => (
  <span className="ecom-loader-spin" aria-hidden="true">
    Loading
  </span>
);

export default ImageCropUploadModal;

