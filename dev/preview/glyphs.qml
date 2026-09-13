import QtQuick
import qs.domain.theme
import qs.ui.primitives

Rectangle {
    color: Theme.s1
    Flow {
        x: 10; y: 10; width: parent.width - 20; spacing: 6
        Repeater {
            model: ["volume_off","volume_mute","volume_down","volume_up","mic","mic_off","signal_wifi_0_bar","network_wifi_1_bar","network_wifi_2_bar","network_wifi_3_bar","signal_wifi_4_bar","signal_disconnected","lan","signal_wifi_bad","signal_wifi_off","bluetooth_disabled","bluetooth","bluetooth_connected","battery_full","battery_1_bar","battery_5_bar","battery_alert","battery_charging_20","battery_charging_30","battery_charging_50","battery_charging_60","battery_charging_80","battery_charging_90","battery_charging_full","eco","speed","balance","brightness_low","brightness_medium","brightness_high","nightlight","bedtime_off","light_mode","dark_mode","blur_on","search","grid_view","notifications","notifications_off","power_settings_new","content_paste","keyboard","videocam","play_arrow","pause","expand_less","expand_more","wallpaper","routine","tune","undo","lock","desktop_windows","chevron_right","calendar_month","do_not_disturb_on","vpn_lock","sports_esports","settings","logout","restart_alt","bedtime","skip_next","skip_previous","pause_circle","play_circle","close","push_pin","keep","apps","history","partly_cloudy_day","fingerprint","arrow_forward","check","check_circle","drag_indicator","select_window","view_agenda","palette","memory","edit","cached","downloading","window","more_horiz","open_in_new","visibility_off","add","terminal"]
            Rectangle {
                required property string modelData
                width: 118; height: 38; radius: 6; color: Theme.s2
                Glyph { id: g; x: 6; anchors.verticalCenter: parent.verticalCenter; name: parent.modelData; size: 22 }
                Text { x: 34; width: 82; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData; font.pixelSize: 8; color: Theme.mut; elide: Text.ElideRight }
            }
        }
    }
}
