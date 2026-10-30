// A panel title that opens a menu when pressed: a menu name, an
// application's name, a logo or a status icon. The panel owns the single
// menu window and knows which title is open; while one is, hovering
// another title switches to its menu.

import QtQuick
import QtQuick.Effects
import "ThemeValues.js" as ThemeValues

Item {
    id: title

    required property var panel
    // Its y tells where the panel's top edge is from here.
    required property var itemRow

    // Text and/or a theme picture, with another picture while lit.
    property string text: ""
    property bool bold: false
    property string picture: ""
    property string openPicture: ""
    // A full address used instead of `picture` (icon theme, tray icon).
    property string pictureSource: ""
    property real pictureHeight: 0
    // Use only the picture's shape, painted in the text colour.
    property bool pictureTinted: false
    // Tray programs supply full-colour as well as neutral icons. Inspect the
    // rendered pixels whenever the source changes, retaining coloured artwork.
    property bool pictureAutoTint: false
    property bool pictureIsNeutral: false
    // Gap between text and picture; the text comes first.
    property real textGap: 0

    // The menu's items, in the form MenuBox.qml describes.
    property var menuItems: []
    signal opening()
    signal chosen(int id)
    // Value from 0 to 1.
    signal slid(int id, real value)
    // Pressed without a menu to open.
    signal activated()
    // Up is positive.
    signal scrolled(real notches)

    readonly property bool open: panel.openTitle === title
    // Set by a title that opened something other than a menu.
    property bool held: false
    // Its menu, open or still fading out, or something else it opened.
    readonly property bool lit: (panel.shownTitle === title && panel.menuShowing) || held

    // Each box reaches half a spacing beyond the title, so neighbours touch.
    property real boxOverhang: itemRow.spacing / 2

    readonly property bool showsPicture: picture !== "" || pictureSource !== ""
    readonly property bool showsText: text !== ""
    readonly property real textWidth: showsText ? label.implicitWidth : 0
    readonly property real pictureWidth: showsPicture ? image.width : 0
    width: textWidth + (showsText && showsPicture ? textGap : 0) + pictureWidth
    height: itemRow.height

    readonly property color inkColor: ThemeValues.color(
        lit ? (panel.looks.title_highlight_text_color ?? panel.looks.text_color)
             : panel.looks.text_color)

    Fill {
        visible: title.lit && title.panel.looks.title_highlight !== undefined
        fill: title.panel.looks.title_highlight ?? ({})
        themeDirectory: title.panel.themeDirectory
        x: -title.boxOverhang
        width: title.width + 2 * title.boxOverhang
        y: -title.itemRow.y
        height: title.panel.height
    }

    Text {
        id: label
        visible: title.showsText
        anchors.verticalCenter: parent.verticalCenter
        text: title.text
        color: title.inkColor
        font.family: title.panel.font.family
        font.pixelSize: title.panel.font.size
        font.bold: title.bold
    }

    Image {
        id: image
        visible: title.showsPicture
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        source: {
            if (title.pictureSource !== "") {
                return title.pictureSource
            }
            if (title.picture === "") {
                return ""
            }
            const name = (title.lit && title.openPicture !== "") ? title.openPicture : title.picture
            return "file://" + title.panel.themeDirectory + "/" + name
        }
        // A picture from elsewhere is sized as a square, so an icon theme can pick
        // the right drawing; the theme's own pictures keep their size.
        readonly property bool sized: title.pictureSource !== "" && title.pictureHeight > 0
        height: sized ? title.pictureHeight : implicitHeight
        width: sized ? title.pictureHeight : implicitWidth
        // Render scalable tray artwork above its display resolution so the
        // tint pass retains antialiased edges at small panel sizes.
        sourceSize: sized ? Qt.size(title.pictureHeight * 2, title.pictureHeight * 2) : undefined
        smooth: true
        mipmap: true

        // Whitened, then colourised, so soft edges keep their alpha. (A mask would
        // make every pixel fully in or out and leave jagged edges.)
        layer.enabled: title.pictureTinted || (title.pictureAutoTint && title.pictureIsNeutral)
        layer.smooth: true
        layer.textureSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        layer.effect: MultiEffect {
            brightness: 1.0
            colorization: 1.0
            colorizationColor: title.inkColor
        }
    }

    Canvas {
        id: iconProbe
        width: 32
        height: 32
        opacity: 0
        visible: title.pictureAutoTint
        property string inspectedSource: ""

        function inspect() {
            title.pictureIsNeutral = false
            if (inspectedSource !== "") unloadImage(inspectedSource)
            inspectedSource = image.source.toString()
            if (title.pictureAutoTint && inspectedSource !== "") {
                loadImage(inspectedSource)
                requestPaint()
            }
        }
        onImageLoaded: requestPaint()
        onPaint: {
            if (!isImageLoaded(inspectedSource)) return
            const context = getContext("2d")
            context.clearRect(0, 0, width, height)
            context.drawImage(inspectedSource, 0, 0, width, height)
            const pixels = context.getImageData(0, 0, width, height).data
            let opaqueWeight = 0
            let colourWeight = 0
            for (let i = 0; i < pixels.length; i += 4) {
                const alpha = pixels[i + 3] / 255
                if (alpha < 0.1) continue
                opaqueWeight += alpha
                const spread = Math.max(pixels[i], pixels[i + 1], pixels[i + 2])
                             - Math.min(pixels[i], pixels[i + 1], pixels[i + 2])
                if (spread > 20) colourWeight += alpha
            }
            title.pictureIsNeutral = opaqueWeight > 0 && colourWeight / opaqueWeight < 0.01
        }
        Connections {
            target: image
            function onSourceChanged() { iconProbe.inspect() }
            function onStatusChanged() {
                if (image.status === Image.Ready) iconProbe.inspect()
            }
        }
        Component.onCompleted: inspect()
    }

    MouseArea {
        x: -title.boxOverhang
        width: title.width + 2 * title.boxOverhang
        y: -title.itemRow.y
        height: title.panel.height
        hoverEnabled: true

        onPressed: {
            if (title.menuItems.length > 0) {
                title.panel.toggleMenu(title)
            } else {
                title.activated()
            }
        }
        onEntered: {
            if (title.panel.openTitle !== null && !title.open && title.menuItems.length > 0) {
                title.panel.openMenu(title)
            }
        }
        // The pointer stays here while pressed, even over the menu.
        onPositionChanged: mouse => {
            if (pressed) {
                title.panel.dragTo?.(mapToItem(null, mouse.x, mouse.y))
            }
        }
        onReleased: mouse => title.panel.releaseAt?.(mapToItem(null, mouse.x, mouse.y))
        // One notch of an ordinary wheel is 120 of Qt's units.
        onWheel: wheel => title.scrolled(wheel.angleDelta.y / 120)
    }

    // The panel's list of titles, for moving between menus by key.
    Component.onCompleted: panel.registerTitle?.(title)
    Component.onDestruction: panel.forgetTitle?.(title)
}
