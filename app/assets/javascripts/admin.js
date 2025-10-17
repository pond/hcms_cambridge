//= require jquery
//= require jquery_ujs
//= require redactor3_rails
//= require redactor
//= require redactor_plugins/alignment
//= require redactor_plugins/fontcolor
//= require redactor_plugins/fontsize
//= require redactor_plugins/properties
//= require redactor_plugins/table
//= require redactor_plugins/video
//= require redactor_plugins/widget
//= require redactor_config.js

$(document).on('ready page:load', function() {
  const pageTypeSelector = $('#page_page_type');
  const eventOnArchiveSelector = $('#event_on_archive_action');

  if (pageTypeSelector.length > 0) {
    function setVisibilities() {
      var selectedPageType = pageTypeSelector.children("option:selected").val();

      if (selectedPageType == 'blog' || selectedPageType == 'events') {
        $('.non-blog-or-events-fields').slideUp();
      } else {
        $('.non-blog-or-events-fields').slideDown();
      }

      if (selectedPageType.endsWith('_form')) {
        $('.is-form-fields').slideDown();

        if (selectedPageType == 'booking_form') {
          $('.is-booking-fields').slideDown();
        } else {
          $('.is-booking-fields').slideUp();
        }
      } else {
        $('.is-form-fields').slideUp();
      }
    }

    setVisibilities();

    pageTypeSelector.change(function(event) {
      setVisibilities();
    });
  }

  if (eventOnArchiveSelector.length > 0) {
    function setVisibilities() {
      var selectedOnArchiveAction = eventOnArchiveSelector.children("option:selected").val();

      if (selectedOnArchiveAction == 'move') {
        $('#on-archive-action-move-fields').slideDown();
      } else {
        $('#on-archive-action-move-fields').slideUp();
      }
    }

    setVisibilities();

    eventOnArchiveSelector.change(function(event) {
      setVisibilities();
    });
  }
});
