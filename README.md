# MacPaint

<p align="center">
<img src="MacPaint/Assets.xcassets/AppIcon.appiconset/macPaint (1) 1.png" alt="MacPaint Logo" width="50" style="border-radius: 10;"/>
</p>

<p align="center">
A modern, native macOS painting application built entirely with <b>SwiftUI</b>.

MacPaint combines the nostalgia of classic bitmap editors with the power of modern vector-based rendering.

</p>

## 🎨 Overview

MacPaint is a lightweight, open-source graphics editor for macOS. Unlike traditional raster paint apps, MacPaint stores every stroke, shape, and text as an object. This allows for non-destructive editing—you can move, resize, and recolor any element on the canvas at any time, even after drawing it.

 ## ✨ Key Features

🛠 Powerful Toolset

Brushes: Five distinct styles including Standard, Stitch, Spray (particle-based), Airbrush, and Crayon.

Shapes: Draw Lines, Rectangles, Ellipses, and Polygons.

Text: Insert and edit text directly on the canvas.

Images: Import photos (.png, .jpg, etc.) and resize/position them seamlessly.

## 🍰 Layer Support

Multi-Layer System: Create, delete, hide, and show layers.

Non-Destructive: Layers are independent; clearing one doesn't affect the others.

Active Layer Control: All drawing and selection actions apply strictly to the currently active layer.

## 🖱️ Advanced Selection & Manipulation

Select & Move: Drag to select multiple elements. Click inside the selection to move them.

Live Resizing: Use the sidebar slider to scale selected items up or down without quality loss.

Recolor: Change the color of any selected stroke or shape instantly.

## 🖥️ Infinite Canvas Experience

Zoomable Interface: Zoom in up to 400% for pixel-perfect details.

Resizable Workspace: Drag handles (Right, Bottom, Bottom-Right) to expand the canvas dimensions dynamically.

Scrollable View: Navigate large canvases easily.

## ⌨️ Keyboard Shortcuts

Speed up your workflow with these hotkeys:

| Key | Action |
| --- | --- |
| B | Switch to Brush (Pencil) |
| S | Switch to Selection Tool |
| E | Switch to Eraser |
| L | Draw Line |
| R | Draw Rectangle |
| O | Draw Oval (Ellipse) |
| P | Draw Polygon |
| T | Insert Text |
| X | Clear Active Layer |
| + / - | Increase / Decrease Stroke Size |
| ⌫ (Delete) | Delete Current Selection |
| Cmd + Z | Undo |
| Cmd + Shift + Z | Redo |


## 🚀 Getting Started

Prerequisites

macOS 12.0 (Monterey) or later.

Xcode 13.0 or later.

Installation

Clone the repository:
```
git clone https://github.com/SuryanshKhatri/MacPaint.git
```

Open in Xcode:
Double-click ```MacPaint.xcodeproj```

Run:
Select your Mac as the target and press Cmd + R.

## 🏗️ Architecture

The app uses a Vector-Based Data Model. Instead of manipulating pixels directly on a bitmap, the app stores an array of DrawingElement structs within distinct Layer objects.

Rendering: The Canvas view in SwiftUI iterates through these elements and renders them in real-time.

Performance: This ensures that zooming and resizing are always crisp, and file sizes remain small.

## 🤝 Contributing

Contributions are welcome! If you have ideas for new tools (e.g., Bucket Fill, Eyedropper) or optimizations:

Fork the project.
```
Create your feature branch (git checkout -b feature/AmazingFeature).
Commit your changes (git commit -m 'Add some AmazingFeature').
Push to the branch (git push origin feature/AmazingFeature).
Open a Pull Request.
```
## 📄 License

Distributed under the MIT License. See LICENSE for more information.

<p align="center">
Made with ❤️ using SwiftUI
</p>
<img width="854" height="728" alt="Screenshot 2025-11-29 at 03 33 16" src="https://github.com/user-attachments/assets/da0af165-0046-40c7-9cb2-4c723f05dc04" />
