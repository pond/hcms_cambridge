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

$(document).ready(function() {

  // ===========================================================================
  // Handle changes of Page type
  // ===========================================================================
  //
  const pageTypeSelector = $('#page_page_type');

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

  // ===========================================================================
  // Handle changes of "on archive" action for Events
  // ===========================================================================
  //
  const eventOnArchiveSelector = $('#event_on_archive_action');

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

  // ===========================================================================
  // Copy buttons
  // ===========================================================================
  //
  const copyFromDataButton = $('button.copy_from_data[data-text]');

  if (copyFromDataButton.length > 0) {
    copyFromDataButton.on('click', function(e) {
      text = copyFromDataButton.data('text');
      navigator.clipboard.writeText(text);

      icon = copyFromDataButton.children('i.fa');
      icon.removeClass('fa-copy');
      icon.addClass('fa-check');

      window.setTimeout(
        function() {
          icon.removeClass('fa-check');
          icon.addClass('fa-copy');
        },
        2000
      );
    });
  }

  // ===========================================================================
  // For ad-hoc order changes, calculate price based on number of seats
  // ===========================================================================
  //
  const pricePerSeatCentsHidden = $('#price_per_seat_cents');

  if (pricePerSeatCentsHidden.length > 0) {
    const pricePerSeatCents   = parseInt(pricePerSeatCentsHidden.val());
    const currency            = $('#price_per_seat_currency').val();
    const numberOfSeatsInput  = $('#order_number_of_seats');
    const amountOwedInput     = $('#order_amount_owed');
    var   manualInputDetected = false;

    const formatter = new Intl.NumberFormat(
      navigator.language, {
        style:               'currency',
        currency:            currency,
        currencyDisplay:     'code',
        trailingZeroDisplay: 'stripIfInteger',
      }
    );

    amountOwedInput.on('input', function(e) {
      manualInputDetected = (amountOwedInput.val().trim().length > 0);
    });

    numberOfSeatsInput.on('input', function(e) {
      if (amountOwedInput.val().trim() === '' || manualInputDetected === false) {
        const inputAmount = numberOfSeatsInput.val();

        if (numberOfSeatsInput.val().length > 0) {
          const numberOfSeats   = parseInt(inputAmount);
          const amountOwedCents = numberOfSeats * pricePerSeatCents;

          formatted = formatter.format(amountOwedCents / 100);
          formatted = formatted.replace(currency, '').trim();

          amountOwedInput.val(formatted);
        } else {
          amountOwedInput.val('');
        }
      }
    });
  }
});
