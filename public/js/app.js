$(function() {
    var errorTag = $('#error');
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

    function controlsDisabled(disabled) {
        reloadPhotosTag.prop('disabled', disabled);
        showLicenseTag.prop('disabled', disabled);
        showPrivacyTag.prop('disabled', disabled);
        showIgnoredTag.prop('disabled', disabled);
        selectLicenseTag.prop('disabled', disabled)
    }

    function filterPhotos() {
        photosTag.children('.photo').each(function(index, element) {
            var photoTag = $(element);
            var show = true;

            if (showLicenseVal != '' && !photoTag.hasClass('license-' + showLicenseVal)) {
                show = false;
            }

            if (showPrivacyVal != 'all' && !photoTag.hasClass(showPrivacyVal)) {
                show = false;
            }

            if (showIgnoredVal != 'true' && photoTag.hasClass('ignored')) {
                show = false;
            }

            if (show) {
                photoTag.show();
            } else {
                photoTag.hide();
            }
        });
    }

    function reloadPhotos(params = {}, path = '/photos/1') {
        controlsDisabled(true);
        $.getJSON(path, params, function(data) {
            photosTag.children('.spinner').remove();

            for (let photo of data.photos) {
                let privacy;
                let privacyTag = $('<span class="tag-box">');

                if (photo.public) {
                    privacy = 'public';
                    privacyTag.text('public');
                } else if (photo.friend && photo.family) {
                    privacy = 'friends_family';
                    privacyTag.text('friends&family');
                } else if (photo.friend) {
                    privacy = 'friends';
                    privacyTag.text('friends');
                } else if (photo.family) {
                    privacy = 'family';
                    privacyTag.text('family');
                } else {
                    privacy = 'private';
                    privacyTag.text('private');
                }

                let photoTag = $('<div class="photo" column>').addClass('license-' + photo.license).addClass(privacy);
                let ignoreTag = $('<button>').click(function() {
                    ignore = !photo.ignore;
                    ignoreTag.prop('disabled', true)
                    $.post('/photos', {ignore: ignore, photo: photo.id}, function() {
                        photo.ignore = ignore;

                        if (ignore) {
                            photoTag.addClass('ignored');
                            ignoreTag.removeClass('-bordered').text('ignored');
                        } else {
                            photoTag.removeClass('ignored');
                            ignoreTag.addClass('-bordered').text('ignore');
                        }

                        filterPhotos();

                        ignoreTag.prop('disabled', false)
                    }).fail(function() {
                        ignoreTag.prop('disabled', false)
                    });
                });

                if (photo.ignore) {
                    photoTag.addClass('ignored');
                    ignoreTag.text('ignored');
                } else {
                    ignoreTag.addClass('-bordered').text('ignore');
                }

                let license = licenses[photo.license];

                photoTag.append($('<div class="card-box">').append([
                    $('<a>', {href: photo.url, target: '_blank'}).append($('<img>', {title: photo.title, src: photo.img})),
                    $('<div class="card-content">').append([
                        $('<span>', {class: 'tag-box', title: license.name}).html(license.icon),
                        '<br>',
                        privacyTag,
                        '<br>',
                        ignoreTag,
                    ]),
                ]));
                photosTag.append(photoTag);
            }

            if (data.path) {
                reloadPhotos({}, data.path);
            } else {
                filterPhotos();
                controlsDisabled(false);
            }
        }).fail(function() {
            controlsDisabled(false);
        });
    }

    function showLicense() {
        if (showLicenseVal == showLicenseTag.val()) {
            filterPhotos();
        } else {
            $.post('/user', {show_license: showLicenseTag.val()}, function() {
                showLicenseVal = showLicenseTag.val();
                showLicense();
            }).fail(function() {
                showLicenseTag.val(showLicenseVal);
            });
        }
    }

    function showPrivacy() {
        if (showPrivacyVal == showPrivacyTag.val()) {
            filterPhotos();
        } else {
            $.post('/user', {show_privacy: showPrivacyTag.val()}, function() {
                showPrivacyVal = showPrivacyTag.val();
                showPrivacy();
            }).fail(function() {
                showPrivacyTag.val(showPrivacyVal);
            });
        }
    }

    function showIgnored() {
        if (showIgnoredVal == showIgnoredTag.val()) {
            filterPhotos();
        } else {
            $.post('/user', {show_ignored: showIgnoredTag.val()}, function() {
                showIgnoredVal = showIgnoredTag.val();
                showIgnored();
            }).fail(function() {
                showIgnoredTag.val(showIgnoredVal);
            });
        }
    }

    errorTag.dialog({autoOpen: false, modal: true});
    $(document).ajaxError(function(event, request, settings, error) {
        if (request.responseJSON && request.responseJSON.error) {
            errorTag.text(request.responseJSON.error);
        } else {
            errorTag.empty().append($('<div>').text(request.status + ' ' + error), $('<iframe>', {srcdoc: request.responseText}));
        }
        errorTag.dialog('open');
    });
    reloadPhotosTag.click(function() {
        photosTag.empty().append('<div class="spinner">');
        selectLicenseTag.val('').change();
        reloadPhotos({reload: true});
    });
    showLicenseTag.change(showLicense);
    showPrivacyTag.change(showPrivacy);
    showIgnoredTag.change(showIgnored);
    selectLicenseTag.change(function() {
        applyLicenseTag.prop('disabled', selectLicenseTag.val() == '');
        var license = licenses[selectLicenseTag.val()];
        if (license) {
            licenseLinkTag.html(license.url ? $('<a>', {href: license.url, target: '_blank'}).html(license.iconname) : license.iconname);
        } else {
            licenseLinkTag.empty();
        }
    });
    applyLicenseTag.click(function() {
        console.log(selectLicenseTag.val());
    });

    reloadPhotos();
});
