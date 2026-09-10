// The layout plasmashell builds when it finds no saved configuration for this
// package.
//
// It deliberately does NOT call loadTemplate("org.kde.plasma.desktop.defaultPanel").
// That template is what adds the stock panel, and a stock panel appearing here
// is precisely the failure this project exists to avoid: a shell package that
// ships its own panel while a second shell also draws one leaves two panels
// stacked at the same screen edge.
//
// A panel, when this package has one, comes from the generated applet layout
// written before the package is ever activated -- never from this script.

var desktops = desktopsForActivity(currentActivity());
for (var i = 0; i < desktops.length; ++i) {
    desktops[i].wallpaperPlugin = "org.kde.image";
}
