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
//= require redactor_config
//= require shared

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
  // Handle changes of kind of encounter order starting date/time
  // ===========================================================================
  //
  const encounterOrderStartsAtKindRadios = $('[id^="encounter_order_starts_at_kind_"]');

  if (encounterOrderStartsAtKindRadios.length > 0) {
    const encounterOrderStartsAtKindFixedDateRadio = $('#encounter_order_starts_at_kind_fixed_date');
    const encounterOrderDateTimeInput = $('#encounter_order_starts_at');

    function enableOrDisableDateTimeInput() {
      if (encounterOrderStartsAtKindFixedDateRadio.is(':checked')) {
        encounterOrderDateTimeInput.prop('disabled', false);
      } else {
        encounterOrderDateTimeInput.prop('disabled', true);
      }
    }

    enableOrDisableDateTimeInput();
    encounterOrderStartsAtKindRadios.on('change', enableOrDisableDateTimeInput);
  }

  // ===========================================================================
  // For ad-hoc order or encounter order changes, calculate price based on the
  // number of seats and (for encounters) physical product addition
  // ===========================================================================
  //
  const pricePerSeatCentsHidden  = $('#price_per_seat_cents');
  const pricePhysicalCentsHidden = $('#price_physical_cents');

  if (pricePerSeatCentsHidden.length > 0) {
    const currency            = $('#price_currency').val();
    const hasPhysicalInput    = $('#encounter_order_has_physical');
    const isEncounter         = (hasPhysicalInput.length > 0);
    const pricePerSeatCents   = parseInt(pricePerSeatCentsHidden.val());
    var   pricePhysicalCents;
    var   numberOfSeatsInput;
    var   amountOwedInput;
    var   manualInputDetected = false;

    if (isEncounter) {
      numberOfSeatsInput = $('#encounter_order_number_of_seats');
      amountOwedInput    = $('#encounter_order_amount_owed');
      pricePhysicalCents = parseInt(pricePhysicalCentsHidden.val());
    } else {
      numberOfSeatsInput = $('#order_number_of_seats');
      amountOwedInput    = $('#order_amount_owed');
      pricePhysicalCents = 0;
    }

    const formatter = new Intl.NumberFormat(
      navigator.language, {
        style:               'currency',
        currency:            currency,
        currencyDisplay:     'code',
        trailingZeroDisplay: 'stripIfInteger',
      }
    );

    const integerDivisor = 10 ** formatter.resolvedOptions().maximumFractionDigits;

    amountOwedInput.on('input', function(e) {
      manualInputDetected = (amountOwedInput.val().trim().length > 0);
    });

    function updateTotal() {
      if (amountOwedInput.val().trim() === '' || manualInputDetected === false) {
        const inputAmount = numberOfSeatsInput.val();

        if (numberOfSeatsInput.val().length > 0) {
          const numberOfSeats   = parseInt(inputAmount);
          var   amountOwedCents = numberOfSeats * pricePerSeatCents;

          if (isEncounter && hasPhysicalInput.val() == 'true') {
            amountOwedCents += pricePhysicalCents;
          }

          formatted = formatter.format(amountOwedCents / integerDivisor);
          formatted = formatted.replace(currency, '').trim();

          amountOwedInput.val(formatted);
        } else {
          amountOwedInput.val('');
        }
      }
    }

    updateTotal();
    numberOfSeatsInput.on('input', updateTotal);

    if (isEncounter) {
      const totalExcludesPhysicalHint = $('#encounter_order_total_amount_hint');

      function showOrHideHint() {
        if (hasPhysicalInput.val() == '') {
          totalExcludesPhysicalHint.show()
        } else {
          totalExcludesPhysicalHint.hide()
        }
      }

      showOrHideHint();
      hasPhysicalInput.on('change', function(e) {
        updateTotal();
        showOrHideHint();
      });
    }
  }
});
