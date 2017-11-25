$(function() {
    var reloadPhotosTag = $('#reload_photos');
    var showLicenseTag = $('#show_license');
    var showLicenseVal = showLicenseTag.val();
    var showPrivacyTag = $('#show_privacy');
    var showPrivacyVal = showPrivacyTag.val();
    var showIgnoredTag = $('#show_ignored');
    var showIgnoredVal = showIgnoredTag.val();
    var photosTag = $('#photos');
    var selectLicenseTag = $('#select_license');
    var applyLicenseTag = $('#apply_license');
    var licenseLinkTag = $('#license_link');

    function reloadPhotos(params = {}, path = '/photos/1') {
        reloadPhotosTag.prop('disabled', true)
        selectLicenseTag.prop('disabled', true)
        $.getJSON(path, params, function(data) {
            console.log(data);

            if (data.path) {
                reloadPhotos({}, data.path);
            } else {
                showLicenseTag.change();
                showPrivacyTag.change();
                showIgnoredTag.change();
                reloadPhotosTag.prop('disabled', false);
                selectLicenseTag.prop('disabled', false);
            }
        });
    }

    function showLicense() {
        if (showLicenseVal == showLicenseTag.val()) {
            console.log(showLicenseVal);
        } else {
            $.post('/user', {show_license: showLicenseTag.val()}, function() {
                showLicenseVal = showLicenseTag.val();
                showLicense();
            });
        }
    }

    function showPrivacy() {
        if (showPrivacyVal == showPrivacyTag.val()) {
            console.log(showPrivacyVal);
        } else {
            $.post('/user', {show_privacy: showPrivacyTag.val()}, function() {
                showPrivacyVal = showPrivacyTag.val();
                showPrivacy();
            });
        }
    }

    function showIgnored() {
        if (showIgnoredVal == showIgnoredTag.val()) {
            console.log(showIgnoredVal);
        } else {
            $.post('/user', {show_ignored: showIgnoredTag.val()}, function() {
                showIgnoredVal = showIgnoredTag.val();
                showIgnored();
            });
        }
    }

    reloadPhotosTag.click(function() {
        photosTag.empty();
        selectLicenseTag.val('').change();
        reloadPhotos({reload: true});
    });
    showLicenseTag.change(showLicense);
    showPrivacyTag.change(showPrivacy);
    showIgnoredTag.change(showIgnored);
    selectLicenseTag.change(function() {
        applyLicenseTag.prop('disabled', selectLicenseTag.val() == '');
        licenseLinkTag.empty();
        var license = licenses[selectLicenseTag.val()];
        if (license) {
            licenseLinkTag.append(license.url ? $('<a>', {href: license.url, target: '_blank'}).text(license.name) : license.name);
        }
    });
    applyLicenseTag.click(function() {
        console.log(selectLicenseTag.val());
    });

    reloadPhotos();
});
