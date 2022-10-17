import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3
import "../Controls"

Page {
    id: root
    anchors.fill: parent
    background: Rectangle {
        color: applicationThemeViewModel.pageBackground
    }

    signal navigateFrom()
    signal navigateTo()

    onVisibleChanged: {
        if (!visible) return;

        if (!applicationThemeViewModel.service.firstLoaded) applicationThemeViewModel.service.loadThemes(applicationThemeViewModel.basedOnDark);
    }

    RowLayout {
        id: panelContainer
        anchors.fill: parent
        spacing: 0
        Rectangle {
            color: applicationThemeViewModel.pageVerticalPanel
            width: 40
            Layout.fillHeight: true
            Column {
                IconButton {
                    height: 45
                    width: 40
                    overlayVisible: false
                    iconPath: assetsLocation.iconsPath + "coloreddrawer.svg"
                    iconWidth: 28
                    iconHeight: 28
                    onButtonPressed: {
                        drawer.open();
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            spacing: 2

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                height: 45
                color: applicationThemeViewModel.pageUpperPanel

                PlainText {
                    id: displaySection
                    text: applicationThemeViewModel.selectedMenuItemName
                    anchors.centerIn: parent
                    fontPointSize: 12
                }

                IconButton {
                    id: menuButton
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    height: 26
                    width: 26
                    overlayVisible: false
                    hoverColor: applicationThemeViewModel.filterIconButtonHoverColor
                    iconWidth: 22
                    iconHeight: 22
                    iconPath: assetsLocation.iconsPath + "allreleases.svg"
                    onButtonPressed: {
                        managerMenu.open();
                    }

                    CommonMenu {
                        id: managerMenu
                        width: 330

                        Repeater {
                            model: applicationThemeViewModel.menuItems

                            CommonMenuItem {
                                text: modelData
                                onPressed: {
                                    managerMenu.close();
                                    applicationThemeViewModel.selectedMenuItem = index;
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                color: "transparent"
                Layout.fillHeight: true
                Layout.fillWidth: true

                Item {
                    visible: applicationThemeViewModel.selectedMenuItem === 0
                    anchors.fill: parent

                    Text {
                        text: "Установленные локально"
                    }
                }

                Item {
                    visible: applicationThemeViewModel.selectedMenuItem === 1
                    anchors.fill: parent

                    ListView {
                        id: externalThemes
                        spacing: 4
                        visible: !applicationThemeViewModel.service.loading && !applicationThemeViewModel.externalThemes.listIsEmpty
                        anchors.fill: parent
                        model: applicationThemeViewModel.externalThemes
                        delegate: Item {
                            width: externalThemes.width
                            height: 200

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                radius: 10
                                color: applicationThemeViewModel.panelBackground
                            }

                            RowLayout {
                                anchors.fill: parent

                                Item {
                                    Layout.preferredWidth: 300
                                    Layout.preferredHeight: 200
                                }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 200

                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: titleTheme.height + authorTheme.height

                                        AccentText {
                                            id: titleTheme
                                            fontPointSize: 12
                                            text: title
                                        }

                                        PlainText {
                                            id: authorTheme
                                            fontPointSize: 10
                                            text: "Автор: " + author
                                        }
                                    }

                                    Column {
                                        width: 50
                                        height: 48
                                        anchors.right: parent.right
                                        anchors.rightMargin: 5
                                        anchors.verticalCenter: parent.verticalCenter

                                        FilterPanelIconButton {
                                            iconPath: assetsLocation.iconsPath + "downloadtheme.svg"
                                            overlayVisible: false
                                            tooltipMessage: "Установить тему"
                                            onButtonPressed: {

                                            }
                                        }
                                        /*FilterPanelIconButton {
                                            iconPath: assetsLocation.iconsPath + "updated.svg"
                                            overlayVisible: false
                                            tooltipMessage: "Обновить тему"
                                            onButtonPressed: {

                                            }
                                        }*/
                                        FilterPanelIconButton {
                                            iconPath: assetsLocation.iconsPath + "delete.svg"
                                            overlayVisible: false
                                            tooltipMessage: "Удалить тему"
                                            onButtonPressed: {

                                            }
                                        }
                                    }

                                }
                            }
                        }
                    }

                    Item {
                        visible: !applicationThemeViewModel.service.loading && applicationThemeViewModel.externalThemes.listIsEmpty
                        anchors.centerIn: parent
                        width: 200
                        height: 200

                        Image {
                            id: emptyExternalItems
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: assetsLocation.iconsPath + "emptybox.svg"
                            width: 80
                            height: 80
                            mipmap: true
                        }
                        PlainText {
                            anchors.top: emptyExternalItems.bottom
                            width: parent.width
                            height: 80
                            fontPointSize: 10
                            text: "Не найдено тем по текущему фильтру"
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                        }
                    }

                    Item {
                        visible: applicationThemeViewModel.service.loading
                        anchors.centerIn: parent
                        width: 200
                        height: 200

                        Image {
                            id: emptyExternalSpinner
                            anchors.horizontalCenter: parent.horizontalCenter
                            source: assetsLocation.iconsPath + "spinner.gif"
                            width: 80
                            height: 80
                            mipmap: true
                        }
                        PlainText {
                            anchors.top: emptyExternalSpinner.bottom
                            fontPointSize: 10
                            text: "Получаем темы..."
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    visible: applicationThemeViewModel.selectedMenuItem === 2
                    anchors.fill: parent

                    Text {
                        text: "Редактор тем"
                    }
                }
            }
        }
    }
}