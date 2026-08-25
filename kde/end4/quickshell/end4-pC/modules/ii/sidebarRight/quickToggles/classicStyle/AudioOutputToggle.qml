import qs.modules.common.models.quickToggles as ToggleModels
import qs.modules.common.widgets

QuickToggleButton {
    id: root

    signal openMenu()

    property ToggleModels.QuickToggleModel toggleModel: ToggleModels.AudioToggle {}

    enabled: toggleModel.available
    toggled: toggleModel.toggled
    buttonIcon: toggleModel.icon
    onClicked: toggleModel.mainAction()
    altAction: () => root.openMenu()

    StyledToolTip {
        text: root.toggleModel.tooltipText
    }
}
