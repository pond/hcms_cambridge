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
  function setVisibilities() {
    var selectedPageType = $('#page_page_type').children("option:selected").val();

    if (selectedPageType == 'blog') {
      $('.non-blog-fields').slideUp();
    } else {
      $('.non-blog-fields').slideDown();
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

  $('#page_page_type').change(function(event) {
    setVisibilities();
  });
});
