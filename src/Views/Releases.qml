/*
    AniLibria - desktop client for the website anilibria.tv
    Copyright (C) 2020 Roman Vladimirov

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.3
import QtWebEngine 1.8
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.2
import QtGraphicalEffects 1.0
import "../Controls"
import "../Theme"

Page {
    id: page
    property bool selectMode
    property var selectedReleases: []
    property var favoriteReleases: []
    property var scheduledReleases: ({})
    property int pageIndex: 1
    property var openedRelease: null
    property bool runRefreshFavorties: false
    property bool synchronizeEnabled: false
    property int selectedSection: 0
    property var seenMarks: ({})
    property bool fillingReleases: false
    property int startedSection: 0
    property string releaseDescription: ""
    property var sectionSortings: {
        0: { field: 0, direction: 1 },
        1: { field: 0, direction: 1 },
        2: { field: 0, direction: 1 },
        3: { field: 0, direction: 1 },
        4: { field: 0, direction: 1 },
        5: { field: 1, direction: 0 },
        6: { field: 0, direction: 1 },
        7: { field: 7, direction: 1 },
        8: { field: 8, direction: 1 },
        9: { field: 0, direction: 1 },
        10: { field: 0, direction: 1 },
        11: { field: 0, direction: 1 },
        12: { field: 0, direction: 1 },
    }
    property bool showButtonVisibleChanger: false
    property bool hideCinemahallButton: false
    property bool hideDownloadButton: false
    property bool hideRandomReleaseButton: false
    property bool hideNotificationButton: false
    property bool hideInfoButton: false
    property bool hideSortButton: false
    property bool hideFilterButton: false
    property bool showAlpabeticalCharaters: false
    property bool toggler: false
    property alias backgroundImageWidth: itemsContainer.width
    property alias backgroundImageHeight: itemsContainer.height

    signal navigateFrom()
    signal watchSingleRelease(int releaseId, string videos, int startSeria, string poster)
    signal refreshReleases()
    signal refreshFavorites()
    signal refreshReleaseSchedules()
    signal requestSynchronizeReleases()
    signal navigateTo()
    signal watchCinemahall()
    signal watchMultipleReleases(var ids)

    Keys.onPressed: {
        if (event.key === Qt.Key_Escape) {
            if (releasePosterPreview.isVisible) {
                releasePosterPreview.isVisible = false;
                if (Qt.platform.os !== "windows") webView.visible = true;
            } else {
                page.openedRelease = null;
                page.showAlpabeticalCharaters = false;
            }
        }
    }

    onWidthChanged: {
        const columnCount = parseInt(page.width / 520);
    }

    onRefreshReleases: {
        refreshAllReleases(false);
    }

    onRefreshReleaseSchedules: {
        refreshSchedule();
    }

    onRefreshFavorites: {
        page.favoriteReleases = localStorage.getFavorites().map(a => a);
    }

    onNavigateTo: {
        refreshSeenMarks();
        refreshAllReleases(true);
    }

    background: Rectangle {
        color: ApplicationTheme.pageBackground
    }

    anchors.fill: parent

    ListModel {
        id: releasesModel
        property int updateCounter: 0
    }

    Rectangle {
        id: mask
        width: 180
        height: 260
        radius: 10
        visible: false
    }

    Rectangle {
        id: cardMask
        width: 180
        height: 260
        radius: 6
        visible: false
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: {
            if (!compactModeSwitch.checked) return;
            if (mouse.x < 80) releasesViewModel.showSidePanel = true;
            if (mouse.x > 100) releasesViewModel.showSidePanel = false;
        }
    }

    RowLayout {
        id: panelContainer
        anchors.fill: parent
        spacing: 0
        enabled: !page.openedRelease
        Rectangle {
            color: ApplicationTheme.pageVerticalPanel
            Layout.preferredWidth: compactModeSwitch.checked && !releasesViewModel.showSidePanel ? 0 : 40
            Layout.fillHeight: true

            Column {
                visible: !compactModeSwitch.checked || releasesViewModel.showSidePanel
                width: compactModeSwitch.checked && !releasesViewModel.showSidePanel ? 0 : 40

                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/menu.svg"
                    iconWidth: 29
                    iconHeight: 29
                    tooltipMessage: "Открыть меню приложения"
                    onButtonPressed: {
                        drawer.open();
                    }
                }

                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/refresh.svg"
                    iconWidth: 34
                    iconHeight: 34
                    tooltipMessage: "Выполнить синхронизацию релизов"
                    onButtonPressed: {
                        if (page.synchronizeEnabled) return;

                        page.requestSynchronizeReleases();
                    }
                }

                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/favorite.svg"
                    iconWidth: 29
                    iconHeight: 29
                    tooltipMessage: "Добавить или удалить релизы из избранного"
                    onButtonPressed: {
                        if (!page.selectedReleases.length) {
                            favoritePopupHeader.text = "Избранное не доступно";
                            favoritePopupMessage.text = "Выберите релизы в списке путем изменения переключателя выше списка на множественный режим и нажатием ЛКМ на интересующих релизах в списке. Выбранные релизы подсвечиваются красной рамкой. Чтобы увидеть свое избранное нажмите на такую же кнопку выше списка релизов.";
                            messagePopup.open();
                            return;
                        }

                        if (!window.userModel.login) {
                            favoritePopupHeader.text = "Избранное не доступно";
                            favoritePopupMessage.text = "Чтобы добавлять в избранное нужно вначале авторизоваться. Для этого перейдите на страницу Войти в меню и войдите под данными своего аккаунта. Если вы не зарегистрированы то необходимо сделать это на сайте, ссылка на сайт будет на странице Войти.";
                            messagePopup.open();
                            return;
                        }

                        favoriteMenu.open();
                    }

                    CommonMenu {
                        id: favoriteMenu
                        y: parent.height
                        width: 350

                        CommonMenuItem {
                            text: "Добавить в избранное"
                            onPressed: {
                                synchronizationService.addUserFavorites(applicationSettings.userToken, page.selectedReleases.join(','));
                                page.selectedReleases = [];
                            }
                        }
                        CommonMenuItem {
                            text: "Удалить из избранного"
                            onPressed: {
                                synchronizationService.removeUserFavorites(applicationSettings.userToken, page.selectedReleases.join(','));
                                page.selectedReleases = [];
                            }
                        }
                    }

                    Popup {
                        id: messagePopup
                        x: window.width / 2 - 225
                        y: window.height / 2 - 100
                        width: 450
                        height: 150
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Column {
                            width: parent.width
                            spacing: 10
                            AccentText {
                                id: favoritePopupHeader
                                width: messagePopup.width - 20
                                fontPointSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                color: "transparent"
                                width: messagePopup.width - 20
                                height: messagePopup.height - 50
                                PlainText {
                                    id: favoritePopupMessage
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    fontPointSize: 10
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/seenmarkpanel.svg"
                    iconWidth: 29
                    iconHeight: 29
                    tooltipMessage: "Отметить релизы как просмотренные или не просмотренные"
                    onButtonPressed: {
                        seenMarkMenuPanel.open();
                    }

                    CommonMenu {
                        id: seenMarkMenuPanel
                        y: parent.height
                        width: 350

                        CommonMenuItem {
                            text: "Отметить как просмотренное"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                setSeenStateForRelease(true, page.selectedReleases);
                            }
                        }
                        CommonMenuItem {
                            text: "Отметить как не просмотренное"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                setSeenStateForRelease(false, page.selectedReleases);
                            }
                        }
                        CommonMenuItem {
                            text: "Удалить все отметки о просмотре"
                            onPressed: {
                                seenMarkMenuPanel.close();
                                removeAllSeenMark.open();
                            }
                        }
                        CommonMenuItem {
                            text: "Скрыть выбранные релизы"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                seenMarkMenuPanel.close();
                                addToHidedReleasesConfirm.open();
                            }
                        }
                        CommonMenuItem {
                            enabled: page.selectedReleases.length
                            text: "Убрать из скрытых выбранные релизы"
                            onPressed: {
                                seenMarkMenuPanel.close();
                                localStorage.removeFromHidedReleases(page.selectedReleases);
                                page.selectedReleases = [];
                            }
                        }
                        CommonMenuItem {
                            text: "Сделать все скрытые релизы видимыми"
                            onPressed: {
                                seenMarkMenuPanel.close();
                                removeAllHidedReleasesConfirm.open();
                            }
                        }
                    }

                    MessageModal {
                        id: addToHidedReleasesConfirm
                        header: "Добавить релизы в скрытые?"
                        message: "Вы уверены что хотите добавить релизы в скрытые?\nЭти релизы будут скрыты везде кроме раздела Скрытые релизы."
                        content: Row {
                            spacing: 6
                            anchors.right: parent.right

                            RoundedActionButton {
                                text: "Ок"
                                width: 100
                                onClicked: {
                                    localStorage.addToHidedReleases(page.selectedReleases);
                                    addToHidedReleasesConfirm.close();
                                    page.selectedReleases = [];
                                }
                            }
                            RoundedActionButton {
                                text: "Отмена"
                                width: 100
                                onClicked: {
                                    addToHidedReleasesConfirm.close();
                                }
                            }
                        }
                    }

                    MessageModal {
                        id: removeAllHidedReleasesConfirm
                        header: "Сделать все релизы видимыми?"
                        message: "Вы уверены что хотите удалить все скрытые релизы?\nЭти релизы будут доступны во всех разделах."
                        content: Row {
                            spacing: 6
                            anchors.right: parent.right

                            RoundedActionButton {
                                text: "Ок"
                                width: 100
                                onClicked: {
                                    localStorage.removeAllHidedReleases(page.selectedReleases);
                                    removeAllHidedReleasesConfirm.close();
                                }
                            }
                            RoundedActionButton {
                                text: "Отмена"
                                width: 100
                                onClicked: {
                                    removeAllHidedReleasesConfirm.close();
                                }
                            }
                        }
                    }

                    MessageModal {
                        id: removeAllSeenMark
                        header: "Удаление признаков просмотра"
                        message: "Вы уверены что хотите удалить все признаки просмотра у всех релизов?"
                        content: Row {
                            spacing: 6
                            anchors.right: parent.right

                            RoundedActionButton {
                                text: "Ок"
                                width: 100
                                onClicked: {
                                    onlinePlayerViewModel.removeAllSeenMark();
                                    refreshSeenMarks();
                                    refreshAllReleases(true);
                                    removeAllSeenMark.close();
                                }
                            }
                            RoundedActionButton {
                                text: "Отмена"
                                width: 100
                                onClicked: {
                                    removeAllSeenMark.close();
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/popcorn.svg"
                    showCrossIcon: page.showButtonVisibleChanger && page.hideCinemahallButton
                    visible: page.showButtonVisibleChanger || !page.hideCinemahallButton
                    tooltipMessage: "Управление кинозалом"
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideCinemahallButton = !page.hideCinemahallButton;
                            localStorage.setHideCinemhallButton(page.hideCinemahallButton);
                        } else {
                            cinemahallMenuPanel.open();
                        }
                    }

                    CommonMenu {
                        id: cinemahallMenuPanel
                        y: parent.height
                        width: 300

                        CommonMenuItem {
                            text: "Добавить в кинозал"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                localStorage.addToCinemahall(page.selectedReleases);
                                page.selectedReleases = [];
                                cinemahallMenuPanel.close();
                            }
                        }
                        CommonMenuItem {
                            text: "Смотреть кинозал"
                            onPressed: {
                                if (localStorage.hasCinemahallReleases()) {
                                    watchCinemahall();
                                } else {
                                    notHaveCinemahallReleasesMessagePopup.open();
                                }
                                cinemahallMenuPanel.close();
                            }
                        }
                    }

                    Popup {
                        id: notHaveCinemahallReleasesMessagePopup
                        x: window.width / 2 - 225
                        y: window.height / 2 - 100
                        width: 450
                        height: 150
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Column {
                            width: parent.width
                            spacing: 10
                            AccentText {
                                id: notHaveCinemahallReleasesHeader
                                width: messagePopup.width - 20
                                fontPointSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                                text: "Просмотр кинозала"
                            }

                            Rectangle {
                                color: "transparent"
                                width: messagePopup.width - 20
                                height: messagePopup.height - 50
                                PlainText {
                                    id: notHaveCinemahallReleasesMessage
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    fontPointSize: 10
                                    wrapMode: Text.WordWrap
                                    text: "У Вас нет релизов в кинозале, чтобы добавить их переведите режим выбора в множественный режим,\n выберите релизы и используйте пункт Добавить в кинозал"
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/downloadcircle.svg"
                    tooltipMessage: "Скачивание файлов серий в разных качествах локально"
                    showCrossIcon: page.showButtonVisibleChanger && page.hideDownloadButton
                    visible: page.showButtonVisibleChanger || !page.hideDownloadButton
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideDownloadButton = !page.hideDownloadButton;
                            localStorage.setHideDownloadButton(page.hideDownloadButton);
                        } else {
                            downloadsMenuPanel.open();
                        }
                    }

                    CommonMenu {
                        id: downloadsMenuPanel
                        y: parent.height
                        width: 300

                        CommonMenuItem {
                            text: "Скачать все серии в HD"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                for (const releaseId of page.selectedReleases) {
                                    const release = findReleaseById(releaseId);
                                    for (let videoId = 0; videoId < release.countVideos; videoId++) {
                                        localStorage.addDownloadItem(release.id, videoId, 1);
                                    }
                                }

                                page.selectedReleases = [];
                                downloadsMenuPanel.close();
                            }
                        }
                        CommonMenuItem {
                            text: "Скачать все серии в SD"
                            enabled: page.selectedReleases.length
                            onPressed: {
                                for (const releaseId of page.selectedReleases) {
                                    const release = findReleaseById(releaseId);
                                    for (let videoId = 0; videoId < release.countVideos; videoId++) {
                                        localStorage.addDownloadItem(release.id, videoId, 2);
                                    }
                                }

                                page.selectedReleases = [];
                                downloadsMenuPanel.close();
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/search.svg"
                    iconWidth: 29
                    iconHeight: 29
                    showCrossIcon: page.showButtonVisibleChanger && page.hideFilterButton
                    visible: page.showButtonVisibleChanger || !page.hideFilterButton
                    tooltipMessage: "Добавить фильтры по дополнительным полям релиза таким как жанры озвучка и т.п."
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideFilterButton = !page.hideFilterButton;
                            localStorage.setHideFilterButton(page.hideFilterButton);
                        } else {
                            filtersPopup.open();
                        }
                    }

                    Rectangle {
                        id: filtersExistsMark
                        visible: descriptionSearchField.text || typeSearchField.text || genresSearchField.text ||
                                 voicesSearchField.text || yearsSearchField.text || seasonesSearchField.text ||
                                 statusesSearchField.text || favoriteMarkSearchField.currentIndex > 0 || seenMarkSearchField.currentIndex > 0
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.topMargin: 10
                        color: "#4ca2c2"
                        width: 16
                        height: 16
                        radius: 12
                    }

                    Popup {
                        id: filtersPopup
                        x: 40
                        y: -200
                        width: 450
                        height: 440
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Rectangle {
                            width: parent.width
                            RoundedActionButton {
                                id: startFilterButton
                                anchors.left: parent.left
                                text: "Фильтровать"
                                onClicked: {
                                    page.refreshAllReleases(false);
                                }
                            }
                            RoundedActionButton {
                                id: clearFiltersButton
                                anchors.right: parent.right
                                text: "Очистить фильтры"
                                onClicked: {
                                    page.clearAdditionalFilters();
                                    page.refreshAllReleases(false);
                                }
                            }
                            PlainText {
                                id: labelDescriptionSearchField
                                anchors.top: clearFiltersButton.bottom
                                fontPointSize: 11
                                text: qsTr("Описание")
                            }
                            PlainText {
                                id: labelTypeSearchField
                                anchors.top: clearFiltersButton.bottom
                                anchors.left: typeSearchField.left
                                fontPointSize: 11
                                text: qsTr("Тип")
                            }
                            TextField {
                                id: descriptionSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelDescriptionSearchField.bottom
                                anchors.rightMargin: 10
                                placeholderText: "Описание"
                            }
                            TextField {
                                id: typeSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelTypeSearchField.bottom
                                anchors.right: parent.right
                                placeholderText: "Тип"
                            }

                            PlainText {
                                id: labelGenresSearchField
                                anchors.top: descriptionSearchField.bottom
                                anchors.rightMargin: 10
                                fontPointSize: 11
                                text: qsTr("Жанры")
                            }
                            TextField {
                                id: genresSearchField
                                width: parent.width * 0.7
                                anchors.top: labelGenresSearchField.bottom
                                placeholderText: "Вводите жанры через запятую"
                            }
                            PlainText {
                                id: labelOrAndGenresSearchField
                                anchors.top: labelGenresSearchField.bottom
                                anchors.left: genresSearchField.right
                                topPadding: 16
                                leftPadding: 4
                                fontPointSize: 11
                                text: qsTr("ИЛИ/И")
                            }
                            Switch {
                                id: orAndGenresSearchField
                                anchors.top: labelGenresSearchField.bottom
                                anchors.left: labelOrAndGenresSearchField.right
                            }

                            PlainText {
                                id: labelVoicesSearchField
                                anchors.top: genresSearchField.bottom
                                anchors.rightMargin: 10
                                fontPointSize: 11
                                text: qsTr("Озвучка")
                            }
                            TextField {
                                id: voicesSearchField
                                width: parent.width * 0.7
                                anchors.top: labelVoicesSearchField.bottom
                                placeholderText: "Вводите войсеров через запятую"
                            }
                            PlainText {
                                id: labelOrAndVoicesSearchField
                                anchors.top: labelVoicesSearchField.bottom
                                anchors.left: voicesSearchField.right
                                topPadding: 16
                                leftPadding: 4
                                fontPointSize: 11
                                text: qsTr("ИЛИ/И")
                            }
                            Switch {
                                id: orAndVoicesSearchField
                                anchors.top: labelVoicesSearchField.bottom
                                anchors.left: labelOrAndVoicesSearchField.right
                            }

                            PlainText {
                                id: labelYearsSearchField
                                anchors.top: voicesSearchField.bottom
                                fontPointSize: 11
                                text: qsTr("Года")
                            }
                            PlainText {
                                id: labelSeasonsSearchField
                                anchors.top: voicesSearchField.bottom
                                anchors.left: typeSearchField.left
                                fontPointSize: 11
                                text: qsTr("Сезоны")
                            }
                            TextField {
                                id: yearsSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelYearsSearchField.bottom
                                anchors.rightMargin: 10
                                placeholderText: "Вводите через запятую"
                            }
                            TextField {
                                id: seasonesSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelSeasonsSearchField.bottom
                                anchors.right: parent.right
                                placeholderText: "Вводите через запятую"
                            }
                            PlainText {
                                id: labelStatusesSearchField
                                anchors.top: yearsSearchField.bottom
                                anchors.rightMargin: 10
                                fontPointSize: 11
                                text: qsTr("Статусы")
                            }
                            TextField {
                                id: statusesSearchField
                                anchors.top: labelStatusesSearchField.bottom
                                anchors.right: parent.right
                                anchors.left: parent.left
                                placeholderText: "Вводите статусы через запятую"
                            }

                            PlainText {
                                id: labelFavoriteMarkSearchField
                                width: parent.width / 2 - 5
                                anchors.top: statusesSearchField.bottom
                                anchors.rightMargin: 10
                                fontPointSize: 11
                                text: qsTr("Признак избранности")
                            }
                            PlainText {
                                id: labelSeenMarkSearchField
                                anchors.top: statusesSearchField.bottom
                                anchors.left: labelFavoriteMarkSearchField.right
                                anchors.rightMargin: 10
                                fontPointSize: 11
                                text: qsTr("Признак просмотра")
                            }
                            CommonComboBox {
                                id: favoriteMarkSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelFavoriteMarkSearchField.bottom
                                anchors.rightMargin: 10
                                model: ListModel {
                                    ListElement {
                                        text: "Не используется"
                                    }
                                    ListElement {
                                        text: "В избранном"
                                    }
                                    ListElement {
                                        text: "Не в избранном"
                                    }
                                }
                            }
                            CommonComboBox {
                                id: seenMarkSearchField
                                width: parent.width / 2 - 5
                                anchors.top: labelFavoriteMarkSearchField.bottom
                                anchors.right: parent.right
                                model: ListModel {
                                    ListElement {
                                        text: "Не используется"
                                    }
                                    ListElement {
                                        text: "Просмотренные"
                                    }
                                    ListElement {
                                        text: "Просматриваемые"
                                    }
                                    ListElement {
                                        text: "Не просмотренные"
                                    }
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/sort.svg"
                    iconWidth: 29
                    iconHeight: 29
                    tooltipMessage: "Указать сортировку списка по одному из полей а также направление сортировки"
                    showCrossIcon: page.showButtonVisibleChanger && page.hideSortButton
                    visible: page.showButtonVisibleChanger || !page.hideSortButton
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideSortButton = !page.hideSortButton;
                            localStorage.setHideSortButton(page.hideSortButton);
                        } else {
                            sortingPopup.open();
                        }
                    }

                    Popup {
                        id: sortingPopup
                        x: 40
                        y: parent.height - 100
                        width: 450
                        height: 200
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Rectangle {
                            width: parent.width
                            RoundedActionButton {
                                id: startSortingButton
                                anchors.right: parent.right
                                text: "Сортировать"
                                onClicked: {
                                    page.refreshAllReleases(false);
                                }
                            }

                            PlainText {
                                id: labelSortingField
                                anchors.top: startSortingButton.bottom
                                fontPointSize: 11
                                text: qsTr("Сортировать по")
                            }
                            CommonComboBox {
                                id: sortingComboBox
                                anchors.top: labelSortingField.bottom
                                anchors.right: parent.right
                                anchors.left: parent.left
                                model: ListModel {
                                    ListElement {
                                        text: "Дате последнего обновления"
                                    }
                                    ListElement {
                                        text: "Дню в расписании"
                                    }
                                    ListElement {
                                        text: "Имени"
                                    }
                                    ListElement {
                                        text: "Году"
                                    }
                                    ListElement {
                                        text: "Рейтингу"
                                    }
                                    ListElement {
                                        text: "Статусу"
                                    }
                                    ListElement {
                                        text: "Оригинальному имени"
                                    }
                                    ListElement {
                                        text: "История"
                                    }
                                    ListElement {
                                        text: "История просмотра"
                                    }
                                    ListElement {
                                        text: "Сезону"
                                    }
                                    ListElement {
                                        text: "Признак избранности"
                                    }
                                    ListElement {
                                        text: "Признак просмотра"
                                    }
                                }
                            }

                            PlainText {
                                id: labelSortingDirection
                                anchors.top: sortingComboBox.bottom
                                fontPointSize: 11
                                text: qsTr("В порядке")
                            }
                            CommonComboBox {
                                id: sortingDirectionComboBox
                                anchors.top: labelSortingDirection.bottom
                                anchors.right: parent.right
                                anchors.left: parent.left
                                currentIndex: 1
                                model: ListModel {
                                    ListElement { text: "Восходящем" }
                                    ListElement { text: "Нисходящем" }
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/notification.svg"
                    iconWidth: 29
                    iconHeight: 29
                    showCrossIcon: page.showButtonVisibleChanger && page.hideNotificationButton
                    tooltipMessage: "Посмотреть уведомления о непросмотренных изменениях в релизах"
                    visible: page.showButtonVisibleChanger || !page.hideNotificationButton
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideNotificationButton = !page.hideNotificationButton;
                            localStorage.setHideNotificationButton(page.hideNotificationButton);
                        } else {
                            notificationPopup.open();
                        }
                    }

                    Rectangle {
                        visible: releasesViewModel.isChangesExists
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.topMargin: 10
                        color: "#4ca2c2"
                        width: 16
                        height: 16
                        radius: 12
                    }

                    Popup {
                        id: notificationPopup
                        x: 40
                        y: parent.height - 100
                        width: 370
                        height: 250
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Rectangle {
                            visible: !releasesViewModel.isChangesExists
                            width: parent.width
                            height: parent.height
                            PlainText {
                                anchors.centerIn: parent
                                text: "У Вас нет новых уведомлений"
                                fontPointSize: 16
                            }
                        }

                        Rectangle {
                            visible: releasesViewModel.isChangesExists
                            width: parent.width
                            RoundedActionButton {
                                id: resetNotificationButton
                                anchors.right: parent.right
                                text: "Отметить все как прочитанное"
                                onClicked: {
                                    releasesViewModel.resetAllChanges();
                                }
                            }
                            Column {
                                spacing: 4
                                anchors.top: resetNotificationButton.bottom
                                Rectangle {
                                    visible: releasesViewModel.newReleasesCount > 0
                                    color: ApplicationTheme.panelBackground
                                    border.width: 3
                                    border.color: ApplicationTheme.selectedItem
                                    width: 340
                                    height: 40

                                    PlainText {
                                        anchors.centerIn: parent
                                        fontPointSize: 11
                                        text: "Новых релизов: " + releasesViewModel.newReleasesCount
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: {
                                            page.changeSection(2);
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: releasesViewModel.newOnlineSeriesCount > 0
                                    color: ApplicationTheme.panelBackground
                                    border.width: 3
                                    border.color: ApplicationTheme.selectedItem
                                    width: 340
                                    height: 40

                                    PlainText {
                                        anchors.centerIn: parent
                                        fontPointSize: 11
                                        text: "Релизов с новыми сериями: " + releasesViewModel.newOnlineSeriesCount
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: {
                                            page.changeSection(3);
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: releasesViewModel.newTorrentsCount > 0
                                    color: ApplicationTheme.panelBackground
                                    border.width: 3
                                    border.color: ApplicationTheme.selectedItem
                                    width: 340
                                    height: 40

                                    PlainText {
                                        anchors.centerIn: parent
                                        fontPointSize: 11
                                        text: "Новые торренты: " + releasesViewModel.newTorrentsCount
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: {
                                            page.changeSection(4);
                                        }
                                    }
                                }
                                Rectangle {
                                    visible: releasesViewModel.newTorrentSeriesCount > 0
                                    color: ApplicationTheme.panelBackground
                                    border.width: 3
                                    border.color: ApplicationTheme.selectedItem
                                    width: 340
                                    height: 40

                                    PlainText {
                                        anchors.centerIn: parent
                                        fontPointSize: 11
                                        text: "Релизы с обновленными торрентами: " + releasesViewModel.newTorrentSeriesCount
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onPressed: {
                                            page.changeSection(6);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/dice.svg"
                    iconWidth: 29
                    iconHeight: 29
                    showCrossIcon: page.showButtonVisibleChanger && page.hideRandomReleaseButton
                    visible: page.showButtonVisibleChanger || !page.hideRandomReleaseButton
                    tooltipMessage: "Открыть карточку релиза выбранного случайным образом"
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideRandomReleaseButton = !page.hideRandomReleaseButton;
                            localStorage.setHideRandomReleaseButton(page.hideRandomReleaseButton);
                        } else {
                            const randomRelease = JSON.parse(localStorage.getRandomRelease());
                            showReleaseCard(randomRelease);
                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/options.svg"
                    iconWidth: 29
                    iconHeight: 29
                    tooltipMessage: "Настройки страницы Каталог релизов"
                    onButtonPressed: {
                        releaseSettingsPopup.open();
                    }

                    Popup {
                        id: releaseSettingsPopup
                        x: 40
                        y: -390
                        width: 370
                        height: 560
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        PlainText {
                            id: downloadTorrentModeLabel
                            fontPointSize: 11
                            text: "Торрент"
                        }
                        CommonComboBox {
                            id: downloadTorrentMode
                            currentIndex: 0
                            anchors.top: downloadTorrentModeLabel.bottom
                            width: 350
                            model: ["Открыть в торрент клиенте", "Сохранить файл"]
                            onCurrentIndexChanged: {
                                localStorage.setTorrentDownloadMode(downloadTorrentMode.currentIndex);
                            }
                        }

                        PlainText {
                            id: notificationForFavoritesLabel
                            anchors.top: downloadTorrentMode.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Уведомления по избранным"
                        }
                        Switch {
                            id: notificationForFavorites
                            anchors.top: notificationForFavoritesLabel.bottom
                            onCheckedChanged: {
                                localStorage.setNotificationForFavorites(checked);
                                releasesViewModel.notificationForFavorites = checked;
                            }
                        }

                        PlainText {
                            id: darkModeLabel
                            anchors.top: notificationForFavorites.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Темная тема"
                        }
                        Switch {
                            id: darkModeSwitch
                            anchors.top: darkModeLabel.bottom
                            onCheckedChanged: {
                                applicationSettings.isDarkTheme = checked;
                                ApplicationTheme.isDarkTheme = checked;
                            }
                        }

                        PlainText {
                            id: clearFilterAfterChangeSectionLabel
                            anchors.top: darkModeSwitch.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Сбрасывать все фильтры после\nсмены раздела"
                        }
                        Switch {
                            id: clearFilterAfterChangeSectionSwitch
                            anchors.top: clearFilterAfterChangeSectionLabel.bottom
                            onCheckedChanged: {
                                localStorage.setClearFiltersAfterChangeSection(checked);
                            }

                            ToolTip.delay: 1000
                            ToolTip.visible: hovered
                            ToolTip.text: "Разделы это кнопки находящиеся по центру выше списка релизов\nДанная настройка влияет на то будут ли сброшены все фильтры при смене раздела или нет"
                        }

                        PlainText {
                            id: compactModeLabel
                            anchors.top: clearFilterAfterChangeSectionSwitch.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Компактный режим"
                        }
                        Switch {
                            id: compactModeSwitch
                            anchors.top: compactModeLabel.bottom
                            onCheckedChanged: {
                                localStorage.setCompactMode(checked);
                            }

                            ToolTip.delay: 1000
                            ToolTip.visible: hovered
                            ToolTip.text: "Компактный режим позволяет уменьшить количество элементов на странице"
                        }

                        PlainText {
                            id: showReleaseDescriptionLabel
                            anchors.top: compactModeSwitch.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Показывать описание в списке"
                        }
                        Switch {
                            id: showReleaseDescriptionSwitch
                            anchors.top: showReleaseDescriptionLabel.bottom
                            onCheckedChanged: {
                                localStorage.setShowReleaseDescription(checked);
                            }

                            ToolTip.delay: 1000
                            ToolTip.visible: hovered
                            ToolTip.text: "Если настройка включена при наведении на релизы будет показываться описание в виде небольшой плашки в нижней части окна"
                        }

                        PlainText {
                            id: useCustomToolbarLabel
                            anchors.top: showReleaseDescriptionSwitch.bottom
                            anchors.topMargin: 4
                            fontPointSize: 11
                            text: "Использовать кастомный тулбар"
                        }
                        Switch {
                            id: useCustomToolbarSwitch
                            anchors.top: useCustomToolbarLabel.bottom
                            onCheckedChanged: {
                                applicationSettings.useCustomToolbar = checked;

                                if (applicationSettings.useCustomToolbar) {
                                    window.flags = Qt.FramelessWindowHint | Qt.Window | Qt.WindowMinimizeButtonHint;
                                    toolBar.visible = true;
                                } else {
                                    window.flags = 1;
                                    toolBar.visible = false;
                                }
                            }

                            ToolTip.delay: 1000
                            ToolTip.visible: hovered
                            ToolTip.text: "Если настройка включена будет использоваться кастомный тулбар окна с дополнительным функционалом"
                        }

                        RoundedActionButton {
                            text: "Настроить фон"
                            anchors.top: useCustomToolbarSwitch.bottom
                            onClicked: {
                                releaseSettingsPopup.close();
                                backgroundImagePopup.open();
                            }
                        }
                    }

                    BackgroundImagePopup {
                        id: backgroundImagePopup
                        x: 40
                        y: -390
                    }
                }

                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/information.svg"
                    iconWidth: 29
                    iconHeight: 29
                    showCrossIcon: page.showButtonVisibleChanger && page.hideInfoButton
                    tooltipMessage: "Просмотреть полезные ссылки связанные с приложением"
                    visible: page.showButtonVisibleChanger || !page.hideInfoButton
                    onButtonPressed: {
                        if (page.showButtonVisibleChanger) {
                            page.hideInfoButton = !page.hideInfoButton;
                            localStorage.setHideInfoButton(page.hideInfoButton);
                        } else {
                            informationPopup.open();
                        }
                    }

                    Popup {
                        id: informationPopup
                        x: 40
                        y: parent.height - 100
                        width: 320
                        height: 96
                        modal: true
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                        Column {
                            LinkedText {
                                fontPointSize: 11
                                text: "<a href='http://anilibriadesktop.reformal.ru/'>Написать идею, ошибку, вопрос?</a>"
                            }
                            LinkedText {
                                fontPointSize: 11
                                text: "<a href='https://t.me/Libria911Bot'>Техподдержка Анилибрии</a>"
                            }
                            LinkedText {
                                fontPointSize: 11
                                text: "<a href='https://www.anilibria.tv'>Сайт анилибрии</a>"
                            }
                            LinkedText {
                                fontPointSize: 11
                                text: "<a href='https://t.me/desktopclientanilibria'>Канал о приложении</a>"
                            }

                        }
                    }
                }
                LeftPanelIconButton {
                    iconPath: "../Assets/Icons/hidebuttonmenu.svg"
                    iconWidth: 29
                    iconHeight: 29
                    backgroundColor: page.showButtonVisibleChanger ? "#8868b0ab" : "transparent"
                    tooltipMessage: "Переключение между режимом добавления/удаления кнопок и обычным меню"
                    onButtonPressed: {
                        page.showButtonVisibleChanger = !page.showButtonVisibleChanger;
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
                color: ApplicationTheme.pageUpperPanel

                Switch {
                    id: multupleMode
                    anchors.left: parent.left
                    onCheckedChanged: {
                        page.selectMode = checked;
                        if (!checked) {
                            page.selectedReleases = [];
                        } else {
                            page.openedRelease = null;
                        }
                    }
                    ToolTip.delay: 1000
                    ToolTip.visible: multupleMode.hovered
                    ToolTip.text: "Данный переключатель влияет на поведение при клике ЛКМ на релизах в списке\nОдиночный выбор позволяет открывать карточку с подробной информацией\nМножественный выбор позволяет выбрать несколько релизов и выполнять действия (добавить в избранное и т.п.)\nЧтобы переключать его можно использовать клик ПКМ в области списка релизов"
                }
                PlainText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 4
                    anchors.left: multupleMode.right
                    fontPointSize: 12
                    text: multupleMode.checked ? "Множественный выбор" : "Одиночный выбор"

                    MouseArea {
                        anchors.fill: parent
                        onPressed: {
                            multupleMode.checked = !multupleMode.checked;
                        }
                    }
                }
                PlainText {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: page.synchronizeEnabled
                    fontPointSize: 12
                    text: "Выполняется синхронизация..."
                }

                RoundedActionButton {
                    id: setToStartedSectionButton
                    visible: page.startedSection !== page.selectedSection
                    text: "Сделать стартовым"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: displaySection.left
                    anchors.rightMargin: 8
                    onClicked: {
                        localStorage.setStartedSection(page.selectedSection);
                        page.startedSection = page.selectedSection;
                    }
                }

                PlainText {
                    id: displaySection
                    text: releasesViewModel.sectionNames[page.selectedSection]
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    fontPointSize: 12
                }
            }

            Rectangle {
                id: filtersContainer
                Layout.preferredWidth: 380
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 36
                color: "transparent"

                Row {
                    width: filtersContainer.width
                    spacing: 8
                    RoundedTextBox {
                        id: filterByTitle
                        width: 250
                        height: 40
                        placeholder: "Введите название релиза"
                        onCompleteEditing: {
                            refreshAllReleases(false);
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/allreleases.svg"
                        tooltipMessage: "Все релизы"
                        onButtonPressed: {
                            changeSection(0);
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/favorite.svg"
                        tooltipMessage: "Избранное"
                        onButtonPressed: {
                            changeSection(1);
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/notification.svg"
                        tooltipMessage: "Показать меню с фильтрами по уведомлениям"
                        onButtonPressed: {
                            notificationsMenuSections.open();
                        }

                        CommonMenu {
                            id: notificationsMenuSections
                            width: 350
                            y: parent.height

                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[2]
                                onPressed: {
                                    page.changeSection(2);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[3]
                                onPressed: {
                                    page.changeSection(3);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[4]
                                onPressed: {
                                    page.changeSection(4);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[6]
                                onPressed: {
                                    page.changeSection(6);
                                }
                            }
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/calendar.svg"
                        iconWidth: 26
                        iconHeight: 26
                        tooltipMessage: "Расписание релизов"
                        onButtonPressed: {
                            changeSection(5);
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/history.svg"
                        tooltipMessage: "Показать меню с фильтрами по истории и истории просмотра"
                        onButtonPressed: {
                            historyMenuSections.open();
                        }

                        CommonMenu {
                            id: historyMenuSections
                            width: 300
                            y: parent.height

                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[7]
                                onPressed: {
                                    page.changeSection(7);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[8]
                                onPressed: {
                                    page.changeSection(8);
                                }
                            }
                        }
                    }
                    FilterPanelIconButton {
                        id: seenMenuButton
                        iconPath: "../Assets/Icons/seenmarkpanel.svg"
                        tooltipMessage: "Показать меню с фильтрами по состоянию просмотра"
                        onButtonPressed: {
                            seenMenuSections.open();
                        }

                        CommonMenu {
                            id: seenMenuSections
                            width: 300
                            y: parent.height

                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[9]
                                onPressed: {
                                    page.changeSection(9);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[10]
                                onPressed: {
                                    page.changeSection(10);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[11]
                                onPressed: {
                                    page.changeSection(11);
                                }
                            }
                            CommonMenuItem {
                                text: releasesViewModel.sectionNames[12]
                                onPressed: {
                                    page.changeSection(12);
                                }
                            }
                        }
                    }
                    FilterPanelIconButton {
                        iconPath: "../Assets/Icons/alphabet.svg"
                        tooltipMessage: "Показать фильтр для выбора букв алфавита для поиска по первой букве релиза"
                        onButtonPressed: {
                            page.showAlpabeticalCharaters = true;
                        }
                    }
                }
            }

            Rectangle {
                id: itemsContainer
                color: "transparent"
                Layout.fillHeight: true
                Layout.fillWidth: true

                Image {
                    id: backgroundFile
                    asynchronous: true
                    visible: releasesViewModel.imageBackgroundViewModel.isHasImage
                    fillMode: releasesViewModel.imageBackgroundViewModel.imageMode
                    source: releasesViewModel.imageBackgroundViewModel.processedImagePath
                    opacity: releasesViewModel.imageBackgroundViewModel.opacity / 100
                    width: releasesViewModel.imageBackgroundViewModel.imageWidth
                    height: releasesViewModel.imageBackgroundViewModel.imageHeight
                    x: releasesViewModel.imageBackgroundViewModel.imageX
                    y: releasesViewModel.imageBackgroundViewModel.imageY
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton | Qt.MiddleButton
                    onWheel: {
                        if (wheel.angleDelta.y < 0) scrollview.flick(0, -800);
                        if (wheel.angleDelta.y > 0) scrollview.flick(0, 800);
                    }
                    onPressed: {
                        multupleMode.checked = !multupleMode.checked;
                    }
                }

                Rectangle {
                    color: "transparent"
                    anchors.fill: parent
                    visible: releasesModel.count === 0

                    PlainText {
                        anchors.centerIn: parent
                        fontPointSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        text: releasesViewModel.countReleases > 0 ? "По текущему фильтру ничего не найдено\nПопробуйте указать другие фильтры или раздел и повторить поиск" : "Релизы еще не загружены\nПожалуйста подождите пока они загрузятся"
                    }
                }

                GridView {
                    id: scrollview
                    visible: releasesModel.count > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: parent.height
                    width: parent.width//Math.floor(window.width / 490) * 490
                    cellWidth: parent.width / Math.floor(parent.width / 490)
                    cellHeight: 290
                    delegate: releaseDelegate
                    model: releasesModel
                    clip: true
                    ScrollBar.vertical: ScrollBar {
                        active: true
                    }
                    onContentYChanged: {
                        if (page.fillingReleases) return;

                        if (scrollview.atYEnd) {
                            page.fillingReleases = true;
                            fillNextReleases();
                            page.fillingReleases = false;
                        }

                    }

                    Component {
                        id: releaseDelegate
                        Rectangle {
                            color: "transparent"
                            width: scrollview.cellWidth
                            height: scrollview.cellHeight

                            ReleaseItem {
                                anchors.centerIn: parent
                                releaseModel: modelData
                                favoriteReleases: page.favoriteReleases
                                isSelected: page.selectedReleases.filter(a => a === releaseModel.id).length

                                onLeftClicked: {
                                    if (page.openedRelease) return;

                                    page.selectItem(modelData);
                                }
                                onRightClicked: {
                                    multupleMode.checked = !multupleMode.checked;
                                }
                                onAddToFavorite: {
                                    synchronizationService.addUserFavorites(applicationSettings.userToken, modelData.id.toString());
                                    page.selectedReleases = [];
                                }
                                onRemoveFromFavorite: {
                                    synchronizationService.removeUserFavorites(applicationSettings.userToken, modelData.id.toString());
                                    page.selectedReleases = [];
                                }
                                onWatchRelease: {
                                    page.watchSingleRelease(id, videos, -1, poster);
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        scrollview.maximumFlickVelocity = scrollview.maximumFlickVelocity - 1050;
                    }
                }
            }
        }
    }

    Rectangle {
        color: "transparent"
        width: 190
        height: 50
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom

        RoundedActionButton {
            id: watchMultipleButton
            visible: page.selectedReleases.length
            text: qsTr("Смотреть выбранное")
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            opacity: 0.8
            onClicked: {
                watchMultipleReleases(page.selectedReleases);

                page.selectedReleases = [];
            }
        }
        IconButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 8
            visible: scrollview.contentY > 100
            height: 30
            width: 30
            iconColor: ApplicationTheme.filterIconButtonColor
            hoverColor: ApplicationTheme.filterIconButtonHoverColor
            iconPath: "../Assets/Icons/arrowup.svg"
            iconWidth: 24
            iconHeight: 24
            ToolTip.delay: 1000
            ToolTip.visible: hovered
            ToolTip.text: "Вернуться в начало списка релизов"
            onButtonPressed: {
                scrollview.contentY = 0;
            }

        }
    }

    ColumnLayout {
        id: cardContainer
        visible: page.openedRelease ? true : false
        anchors.fill: parent
        spacing: 0
        Rectangle {
            color: ApplicationTheme.pageBackground
            Layout.fillWidth: true
            Layout.fillHeight: true
            Column {
                Grid {
                    id: releaseInfo
                    columnSpacing: 3
                    columns: 3
                    bottomPadding: 4
                    leftPadding: 4
                    topPadding: 4
                    rightPadding: 4
                    Image {
                        id: cardPoster
                        source: page.openedRelease ? localStorage.getReleasePosterPath(page.openedRelease.id, page.openedRelease.poster) : '../Assets/Icons/donate.jpg'
                        fillMode: Image.PreserveAspectCrop
                        width: 280
                        height: 390
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: cardMask
                        }

                        MouseArea {
                            anchors.fill: parent
                            onPressed: {
                                releasePosterPreview.isVisible = true;
                                if (Qt.platform.os !== "windows") webView.visible = false;
                            }
                        }
                    }
                    Column {
                        width: page.width - cardButtons.width - cardPoster.width
                        enabled: !!page.openedRelease
                        AccentText {
                            textFormat: Text.RichText
                            fontPointSize: 12
                            width: parent.width
                            leftPadding: 8
                            topPadding: 6
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            text: qsTr(page.openedRelease ? page.openedRelease.title : '')
                        }
                        PlainText {
                            textFormat: Text.RichText
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            wrapMode: Text.WordWrap
                            width: parent.width
                            maximumLineCount: 2
                            text: qsTr(page.openedRelease ? page.openedRelease.originalName : '')
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            text: qsTr("<b>Статус:</b> ") + qsTr(page.openedRelease ? `<a href="http://years">${page.openedRelease.status}</a>` : '')
                            onLinkActivated: {
                                statusesSearchField.text = page.openedRelease.status;
                                page.openedRelease = null;
                                page.refreshAllReleases(false);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            text: qsTr("<b>Год:</b> ") + qsTr(page.openedRelease ?  `<a href="http://years">${page.openedRelease.year}</a>` : '')
                            onLinkActivated: {
                                yearsSearchField.text = page.openedRelease.year;
                                page.openedRelease = null;
                                page.refreshAllReleases(false);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        PlainText {
                            visible: page.openedRelease && page.openedRelease.id && !!page.scheduledReleases[page.openedRelease.id]
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            text: qsTr("<b>В расписании:</b> ") + (page.openedRelease && page.scheduledReleases[page.openedRelease.id] ? releasesViewModel.getScheduleDay(page.scheduledReleases[page.openedRelease.id]) : '')
                        }

                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            text: qsTr("<b>Сезон:</b> ") + qsTr(page.openedRelease ? `<a href="http://seasons">${page.openedRelease.season}</a>` : '')
                            onLinkActivated: {
                                seasonesSearchField.text = page.openedRelease.season;
                                page.openedRelease = null;
                                page.refreshAllReleases(false);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        PlainText {
                            textFormat: Text.RichText
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            text: qsTr("<b>Тип:</b> ") + qsTr(page.openedRelease ? page.openedRelease.type : '')
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            text: qsTr("<b>Жанры:</b> ") + qsTr(page.openedRelease ? getMultipleLinks(page.openedRelease.genres) : '')
                            onLinkActivated: {
                                if (genresSearchField.text.length) {
                                    genresSearchField.text += ", " + link;
                                } else {
                                    genresSearchField.text = link;
                                }
                                page.openedRelease = null;
                                page.refreshAllReleases(false);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            width: parent.width
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            text: qsTr("<b>Озвучка:</b> ") + qsTr(page.openedRelease ? getMultipleLinks(page.openedRelease.voices) : '')
                            onLinkActivated: {
                                if (voicesSearchField.text.length) {
                                    voicesSearchField.text += ", " + link;
                                } else {
                                    voicesSearchField.text = link;
                                }
                                page.openedRelease = null;
                                page.refreshAllReleases(false);
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            visible: page.openedRelease ? page.openedRelease.countSeensSeries === page.openedRelease.countVideos : false
                            width: parent.width
                            text: qsTr("<b>Все серии просмотрены</b>")
                        }
                        PlainText {
                            fontPointSize: 10
                            leftPadding: 8
                            topPadding: 4
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: qsTr("<b>Описание:</b> ") + qsTr(page.openedRelease ? page.openedRelease.description : '')
                            onLinkActivated: {
                                if (link.indexOf("https://www.anilibria.tv/release/") === 0 || link.indexOf("http://www.anilibria.tv/release/") === 0) {
                                    let code = link.replace("https://www.anilibria.tv/release/", "").replace("http://www.anilibria.tv/release/", "").replace(".html", "")
                                    if (code.indexOf(`?`) > -1) code = code.substring( 0, code.indexOf(`?`));
                                    const release = JSON.parse(localStorage.getReleaseByCode(code));
                                    showReleaseCard(release);
                                } else {
                                    Qt.openUrlExternally(link);
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor
                            }
                        }
                    }
                    Column {
                        id: cardButtons
                        width: 62
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/close.svg"
                            iconWidth: 28
                            iconHeight: 28
                            onButtonPressed: {
                                page.openedRelease = null;
                            }
                        }
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/copy.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (Qt.platform.os !== "windows") webView.visible = false;
                                cardCopyMenu.open();
                            }

                            TextEdit {
                                id: hiddenTextField
                                visible: false
                            }

                            CommonMenu {
                                id: cardCopyMenu
                                width: 350
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                CommonMenuItem {
                                    text: "Копировать название"
                                    onPressed: {
                                        releasesViewModel.copyToClipboard(page.openedRelease.title);
                                    }
                                }
                                CommonMenuItem {
                                    text: "Копировать оригинальное название"
                                    onPressed: {
                                        releasesViewModel.copyToClipboard(page.openedRelease.originalName);
                                    }
                                }
                                CommonMenuItem {
                                    text: "Копировать оба названия"
                                    onPressed: {
                                        releasesViewModel.copyToClipboard(page.openedRelease.title + ", " + page.openedRelease.originalName);
                                    }
                                }
                                CommonMenuItem {
                                    text: "Копировать описание"
                                    onPressed: {
                                        releasesViewModel.copyToClipboard(page.openedRelease.description);
                                    }
                                }
                                CommonMenuItem {
                                    text: "Копировать постер"
                                    onPressed: {
                                        const currentOpened = page.openedRelease;
                                        releasesViewModel.copyImageToClipboard(localStorage.getReleasePosterPath(currentOpened.id, currentOpened.poster));
                                    }
                                }

                            }
                        }
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/vk.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (Qt.platform.os !== "windows") webView.visible = false;
                                vkontakteMenu.open();
                            }

                            CommonMenu {
                                id: vkontakteMenu
                                width: 350
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                CommonMenuItem {
                                    text: "Авторизоваться для комментариев"
                                    onPressed: {
                                        webView.url = "https://oauth.vk.com/authorize?client_id=-1&display=widget&widget=4&redirect_uri=https://vk.com/";
                                    }
                                }
                                CommonMenuItem {
                                    text: "Переоткрыть комментарии"
                                    onPressed: {
                                        webView.url = releasesViewModel.getVkontakteCommentPage(page.openedRelease.code);
                                    }
                                }
                            }
                        }
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/seenmarkpanel.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (Qt.platform.os !== "windows") webView.visible = false;
                                seenMarkMenu.open();
                            }

                            CommonMenu {
                                id: seenMarkMenu
                                width: 350
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                CommonMenuItem {
                                    text: "Отметить как просмотренное"
                                    onPressed: {
                                        setSeenStateForOpenedRelease(true);
                                    }
                                }
                                CommonMenuItem {
                                    text: "Отметить как не просмотренное"
                                    onPressed: {
                                        setSeenStateForOpenedRelease(false);
                                    }
                                }                                
                                CommonMenuItem {
                                    id: hideReleaseCardMenu
                                    enabled: page.openedRelease && !localStorage.isReleaseInHided(page.openedRelease.id)
                                    text: "Скрыть релиз"
                                    onPressed: {
                                        localStorage.addToHidedReleases([page.openedRelease.id]);
                                        hideReleaseCardMenu.enabled = false;
                                        removeFromHideReleaseCardMenu.enabled = true;
                                        seenMarkMenu.close();
                                    }
                                }
                                CommonMenuItem {
                                    id: removeFromHideReleaseCardMenu
                                    enabled: page.openedRelease && localStorage.isReleaseInHided(page.openedRelease.id)
                                    text: "Убрать релиз из скрытых"
                                    onPressed: {
                                        localStorage.removeFromHidedReleases([page.openedRelease.id]);
                                        hideReleaseCardMenu.enabled = true;
                                        removeFromHideReleaseCardMenu.enabled = false;
                                        seenMarkMenu.close();
                                    }
                                }
                            }
                        }
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: page.openedRelease && page.favoriteReleases.filter(a => a === page.openedRelease.id).length ? ApplicationTheme.selectedFavorite : ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/favorite.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (!window.userModel.login) {
                                    favoritePopupHeader.text = "Избранное не доступно";
                                    favoritePopupMessage.text = "Чтобы добавлять в избранное нужно вначале авторизоваться. Для этого перейдите на страницу Войти в меню и войдите под данными своего аккаунта. Если вы не зарегистрированы то необходимо сделать это на сайте, ссылка на сайт будет на странице Войти.";
                                    messagePopup.open();
                                    return;
                                }

                                if (Qt.platform.os !== "windows") webView.visible = false;
                                cardFavoritesMenu.open();
                            }

                            CommonMenu {
                                id: cardFavoritesMenu
                                width: 350
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                CommonMenuItem {
                                    enabled: page.openedRelease && !page.favoriteReleases.filter(a => a === page.openedRelease.id).length
                                    text: "Добавить в избранное"
                                    onPressed: {
                                        synchronizationService.addUserFavorites(applicationSettings.userToken, page.openedRelease.id.toString());
                                        page.selectedReleases = [];
                                    }
                                }
                                CommonMenuItem {
                                    enabled: page.openedRelease && page.favoriteReleases.filter(a => a === page.openedRelease.id).length
                                    text: "Удалить из избранного"
                                    onPressed: {
                                        synchronizationService.removeUserFavorites(applicationSettings.userToken, page.openedRelease.id.toString());
                                        page.selectedReleases = [];
                                    }
                                }
                            }
                        }
                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/external.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (Qt.platform.os !== "windows") webView.visible = false;
                                externalPlayerMenu.open();
                            }

                            CommonMenu {
                                id: externalPlayerMenu
                                width: 380
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                CommonMenuItem {
                                    text: "Открыть во внешнем плеере в HD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsM3UAndOpen(page.openedRelease.id, "hd"));
                                        externalPlayerMenu.close();
                                    }
                                }
                                CommonMenuItem {
                                    text: "Открыть во внешнем плеере в SD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsM3UAndOpen(page.openedRelease.id, "sd"));
                                        externalPlayerMenu.close();
                                    }
                                }
                                CommonMenuItem {
                                    text: "Открыть во внешнем плеере в FullHD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsM3UAndOpen(page.openedRelease.id, "fullhd"));
                                        externalPlayerMenu.close();
                                    }
                                }

                                CommonMenuItem {
                                    notVisible: Qt.platform.os !== "windows"
                                    text: "Открыть в плеере MPC в HD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsMPCPLAndOpen(page.openedRelease.id, "hd"));
                                        externalPlayerMenu.close();
                                    }
                                }
                                CommonMenuItem {
                                    notVisible: Qt.platform.os !== "windows"
                                    text: "Открыть в плеере MPC в SD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsMPCPLAndOpen(page.openedRelease.id, "sd"));
                                        externalPlayerMenu.close();
                                    }
                                }
                                CommonMenuItem {
                                    notVisible: Qt.platform.os !== "windows"
                                    text: "Открыть в плеере MPC в FullHD качестве"
                                    onPressed: {
                                        openInExternalPlayer(localStorage.packAsMPCPLAndOpen(page.openedRelease.id, "fullhd"));
                                        externalPlayerMenu.close();
                                    }
                                }
                            }
                        }

                        IconButton {
                            height: 40
                            width: 40
                            iconColor: ApplicationTheme.filterIconButtonColor
                            hoverColor: ApplicationTheme.filterIconButtonHoverColor
                            iconPath: "../Assets/Icons/online.svg"
                            iconWidth: 26
                            iconHeight: 26
                            onButtonPressed: {
                                if (Qt.platform.os !== "windows") webView.visible = false;
                                setSeriesMenu.open();
                            }

                            CommonMenu {
                                id: setSeriesMenu
                                width: 330
                                onClosed: {
                                    if (Qt.platform.os !== "windows") webView.visible = true;
                                }

                                Repeater {
                                    model: page.openedRelease ? page.openedRelease.countVideos : 0

                                    CommonMenuItem {
                                        text: "Серия " + (index + 1)
                                        onPressed: {
                                            watchSingleRelease(page.openedRelease.id, page.openedRelease.videos, index, page.openedRelease.poster);

                                            page.openedRelease = null;
                                            if (Qt.platform.os !== "windows") webView.visible = true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    color: "transparent"
                    width: cardContainer.width
                    height: 60

                    RoundedActionButton {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        anchors.left: parent.left
                        text: qsTr("Скачать")
                        onClicked: {
                            if (Qt.platform.os !== "windows") webView.visible = false;
                            dowloadTorrent.open();
                        }

                        CommonMenu {
                            id: dowloadTorrent
                            y: parent.height - parent.height
                            width: 380
                            onClosed: {
                                if (Qt.platform.os !== "windows") webView.visible = true;
                            }

                            Repeater {
                                model: releasesViewModel.openedCardTorrents
                                CommonMenuItem {
                                    text: "Скачать " + quality + " [" + series + "] " + size
                                    onPressed: {
                                        const torrentUri = synchronizationService.combineWithWebSiteUrl(url);
                                        synchronizationService.downloadTorrent(torrentUri);
                                    }
                                }
                            }
                        }
                    }

                    PlainText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 100
                        fontPointSize: 11
                        text: "Доступно "+ (page.openedRelease ? page.openedRelease.countTorrents : "0" ) + " торрентов"
                    }

                    PlainText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: watchButton.left
                        anchors.rightMargin: 10
                        fontPointSize: 11
                        text: "Доступно "+ (page.openedRelease ? page.openedRelease.countVideos : "0" ) + " серий онлайн"
                    }

                    RoundedActionButton {
                        id: watchButton
                        text: qsTr("Смотреть")
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        onClicked: {
                            watchSingleRelease(page.openedRelease.id, page.openedRelease.videos, -1, page.openedRelease.poster)

                            page.openedRelease = null;
                            releasePosterPreview.isVisible = false;
                            if (Qt.platform.os !== "windows") webView.visible = true;
                        }
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                    }

                    PlainText {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.centerIn: parent
                        visible: webView.loading
                        fontPointSize: 11
                        text: "Загрузка комментариев..."
                    }
                }
                WebEngineView {
                    id: webView
                    visible: page.openedRelease ? true : false
                    width: cardContainer.width
                    height: cardContainer.height - releaseInfo.height - 60
                }
            }
        }

    }

    Rectangle {
        color: ApplicationTheme.pageBackground
        opacity: 0.8
        visible: page.releaseDescription && page.releaseDescription !== "" && showReleaseDescriptionSwitch.checked
        enabled: false
        anchors.left: parent.left
        anchors.leftMargin: 42
        anchors.bottom: parent.bottom
        anchors.rightMargin: 2
        height: 105
        width: parent.width / 2

        PlainText {
            anchors.fill: parent
            fontPointSize: 11
            text: page.releaseDescription
            wrapMode: Text.WordWrap
            maximumLineCount: 5
            verticalAlignment: Text.AlignVCenter
        }
    }

    ReleaseAlphabeticalCharacters {
        id: releaseAlphabeticalCharacters
        visible: page.showAlpabeticalCharaters
    }

    ReleasePosterPreview {
        id: releasePosterPreview
    }

    function setSeenStateForOpenedRelease(newState) {
        onlinePlayerViewModel.setSeenMarkAllSeries(page.openedRelease.id, page.openedRelease.countVideos, newState);
        page.openedRelease.countSeensSeries = newState ? page.openedRelease.countVideos : 0;
        const oldRelease = page.openedRelease;
        page.openedRelease = null;
        page.openedRelease = oldRelease;
        refreshSeenMarks();
        refreshAllReleases(true);
    }

    function setSeenStateForRelease(newState, releases) {
        for (const releaseId of releases) {
            const release = JSON.parse(localStorage.getRelease(releaseId));
            const videos = JSON.parse(release.videos);
            onlinePlayerViewModel.setSeenMarkAllSeriesWithoutSave(releaseId, videos.length, newState);
        }
        onlinePlayerViewModel.saveSeenMarkCacheToFile();

        page.selectedReleases = [];
        refreshSeenMarks();
        refreshAllReleases(true);
    }

    function selectItem(item) {
        if (page.selectMode) {
            if (page.openedRelease) page.openedRelease = null;
            if (page.selectedReleases.find(a => a === item.id)) {
                page.selectedReleases = page.selectedReleases.filter(a => a !== item.id);
            } else {
                page.selectedReleases.push(item.id);
            }

            //WORKAROUND: fix refresh list
            const oldSelectedReleases = page.selectedReleases;
            page.selectedReleases = [];
            page.selectedReleases = oldSelectedReleases;
        } else {
            showReleaseCard(item);
        }
    }

    function getReleasesByFilter() {
        return JSON.parse(
            localStorage.getReleasesByFilter(
                page.pageIndex,
                filterByTitle.textContent,
                page.selectedSection,
                descriptionSearchField.text,
                typeSearchField.text,
                genresSearchField.text,
                orAndGenresSearchField.checked,
                voicesSearchField.text,
                orAndVoicesSearchField.checked,
                yearsSearchField.text,
                seasonesSearchField.text,
                statusesSearchField.text,
                sortingComboBox.currentIndex,
                sortingDirectionComboBox.currentIndex == 1 ? true : false,
                favoriteMarkSearchField.currentIndex,
                seenMarkSearchField.currentIndex,
                alphabetListModel.getSelectedCharacters()
            )
        );
    }

    function refreshSeenMarks() {
        page.seenMarks = JSON.parse(onlinePlayerViewModel.getSeenMarks());
    }

    function setSeensCounts(releases) {
        for (const release of releases) {
            release.countSeensSeries = 0;
            if (release.id in page.seenMarks) {
                release.countSeensSeries = page.seenMarks[release.id];
            }
        }
    }

    function fillNextReleases() {
        if (releasesModel.count < 12) return;
        if (page.pageIndex === -1) return;

        page.pageIndex += 1;

        const nextPageReleases = getReleasesByFilter();
        setSeensCounts(nextPageReleases);
        for (const displayRelease of nextPageReleases) releasesModel.append({ model: displayRelease });

        if (nextPageReleases.length < 12) page.pageIndex = -1;
    }

    function refreshAllReleases(notResetScroll) {
        if (Object.keys(page.seenMarks).length === 0) refreshSeenMarks();
        page.pageIndex = 1;
        releasesModel.clear();
        const displayReleases = getReleasesByFilter();
        setSeensCounts(displayReleases);
        for (const displayRelease of displayReleases) releasesModel.append({ model: displayRelease });
        if (!notResetScroll) scrollview.contentY = 0;
    }

    function clearAdditionalFilters() {
        descriptionSearchField.text = "";
        typeSearchField.text = "";
        genresSearchField.text = "";
        orAndGenresSearchField.checked = false;
        voicesSearchField.text = "";
        orAndVoicesSearchField.checked = false;
        yearsSearchField.text = "";
        seasonesSearchField.text = "";
        statusesSearchField.text = "";
        favoriteMarkSearchField.currentIndex = 0;
        seenMarkSearchField.currentIndex = 0;
        alphabetListModel.clearCharacters();
    }

    function changeSection(section) {
        if (section === page.selectedSection) return;

        if (clearFilterAfterChangeSectionSwitch.checked) {
            filterByTitle.textContent = "";
            page.clearAdditionalFilters();
        }

        page.selectedSection = section;
        if (section in page.sectionSortings) {
            const defaultSorting = page.sectionSortings[section];
            sortingComboBox.currentIndex = defaultSorting.field;
            sortingDirectionComboBox.currentIndex = defaultSorting.direction;
        }

        refreshAllReleases(false);
    }

    function refreshSchedule() {
        const schedule = localStorage.getSchedule();
        if (schedule) page.scheduledReleases = JSON.parse(schedule);
    }

    function showReleaseCard(release) {
        if (release.id === -1) return;

        releasesViewModel.openedCardTorrents.loadTorrentsFromJson(release.torrents);

        page.openedRelease = release;
        localStorage.setToReleaseHistory(release.id, 0);
        analyticsService.sendView("releasecard", "show", "%2Freleases");

        localStorage.resetReleaseChanges(release.id);

        webView.url = releasesViewModel.getVkontakteCommentPage(page.openedRelease.code);
    }

    function openInExternalPlayer(url) {
        if (!url) return;

        Qt.openUrlExternally(url);
    }

    function getMultipleLinks(text) {
        if (!text) return "";
        let result = "";

        const parts = text.split(",");
        let isFirst = true;
        for (const part of parts) {
            const partData = part.trim();
            result += (!isFirst ? ", " : "") + `<a href="${partData}">${partData}</a>`;
            isFirst = false;
        }

        return result;
    }

    function findReleaseById(id) {
        for (let i = 0; i < releasesModel.count; i++) {
            const release = releasesModel.get(i).model;
            if (release.id === id) return release;
        }

        return null;
    }

    Component.onCompleted: {
        refreshAllReleases(false);
        refreshSchedule();

        const userSettings = JSON.parse(localStorage.getUserSettings());
        downloadTorrentMode.currentIndex = userSettings.torrentDownloadMode;
        notificationForFavorites.checked = userSettings.notificationForFavorites;
        darkModeSwitch.checked = applicationSettings.isDarkTheme;
        clearFilterAfterChangeSectionSwitch.checked = userSettings.clearFiltersAfterChangeSection;
        compactModeSwitch.checked = userSettings.compactMode;
        page.hideCinemahallButton = userSettings.hideCinemhallButton;
        page.hideDownloadButton = userSettings.hideDownloadButton;
        page.hideRandomReleaseButton = userSettings.hideRandomReleaseButton;
        page.hideNotificationButton = userSettings.hideNotificationButton;
        page.hideInfoButton = userSettings.hideInfoButton;
        page.hideSortButton = userSettings.hideSortButton;
        page.hideFilterButton = userSettings.hideFilterButton;
        showReleaseDescriptionSwitch.checked = userSettings.showReleaseDescription;
        useCustomToolbarSwitch.checked = applicationSettings.useCustomToolbar;

        const startedSection = userSettings.startedSection;
        if (startedSection) changeSection(startedSection);
        page.startedSection = startedSection;
    }
}
