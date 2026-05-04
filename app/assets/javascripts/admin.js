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

  // A helper which is called with a jQuery selector and function object. If
  // the selector matches any elements, the function is invoked and passed the
  // jQuery object for the given selector (so you don't have to look up twice).
  //
  const init = (selector, fn) => {
    const $el = $(selector);
    if ($el.length) fn($el);
  };

  // ===========================================================================
  // Handle changes of Page type
  // ===========================================================================
  //
  init('#page_page_type', ($pageTypeSelector) => {
    function setVisibilities() {
      let selectedPageType = $pageTypeSelector.children("option:selected").val();

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
    $pageTypeSelector.change(setVisibilities);
  });

  // ===========================================================================
  // Handle changes of "on archive" action for Events
  // ===========================================================================
  //
  init('#event_on_archive_action', ($eventOnArchiveSelector) => {
    function setVisibilities() {
      let selectedOnArchiveAction = $eventOnArchiveSelector.children("option:selected").val();

      if (selectedOnArchiveAction == 'move') {
        $('#on-archive-action-move-fields').slideDown();
      } else {
        $('#on-archive-action-move-fields').slideUp();
      }
    }

    setVisibilities();
    $eventOnArchiveSelector.change(setVisibilities);
  });

  // ===========================================================================
  // Handle changes of the encounter "Price on application" option
  // ===========================================================================
  //
  init('#encounter_price_on_application', ($encounterPriceOnApplicationCheckbox) => {
    const $encounterPricePerSeatContainer = $('#encounter_price_per_seat_container');

    function setVisibilities() {
      if ($encounterPriceOnApplicationCheckbox.is(':checked')) {
        $encounterPricePerSeatContainer.slideUp();
      } else {
        $encounterPricePerSeatContainer.slideDown();
      }
    }

    setVisibilities();
    $encounterPriceOnApplicationCheckbox.change(setVisibilities);
  });

  // ===========================================================================
  // Handle changes of the encounter "Category" selector
  // ===========================================================================
  //
  init('#encounter_category_chooser', ($encounterCategorySelector) => {
    const $encounterCategoryInput = $('#encounter_category');

    function setVisibilities() {
      let selectedCategory = $encounterCategorySelector.children("option:selected").val();

      if (selectedCategory === "") {
        $encounterCategoryInput.val("");
        $encounterCategoryInput.show();
      } else {
        $encounterCategoryInput.hide();
        $encounterCategoryInput.val(selectedCategory);
      }
    }

    setVisibilities();
    $encounterCategorySelector.change(setVisibilities);
  });

  // ===========================================================================
  // For ad-hoc Order *or* Encounter Order changes, calculate price based on
  // the number of seats and (for encounters) physical product addition
  //
  // This is not appropriate for POA Encounter Orders, so there's an early exit
  // condition for those.
  // ===========================================================================
  //
  init('#price_per_seat_cents', ($pricePerSeatCentsHidden) => {
    const $priceOnApplicationHidden = $('#price_on_application');

    // NOTE EARLY EXIT - Bail out for POA Encounter Orders.
    //
    if ($priceOnApplicationHidden.val() === 'true') return;

    const $pricePhysicalCentsHidden = $('#price_physical_cents');
    const $hasPhysicalInput         = $('#encounter_order_has_physical');
    const currency                  = $('#price_currency').val();
    const isEncounter               = ($hasPhysicalInput.length > 0);
    const pricePerSeatCents         = parseInt($pricePerSeatCentsHidden.val());

    let   $numberOfSeatsInput;
    let   $amountOwedInput;
    let   pricePhysicalCents;
    let   manualInputDetected = false;

    if (isEncounter) {
      $numberOfSeatsInput = $('#encounter_order_number_of_seats');
      $amountOwedInput    = $('#encounter_order_amount_owed');
      pricePhysicalCents  = parseInt($pricePhysicalCentsHidden.val());
    } else {
      $numberOfSeatsInput = $('#order_number_of_seats');
      $amountOwedInput    = $('#order_amount_owed');
      pricePhysicalCents  = 0;
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

    $amountOwedInput.on('input', function(e) {
      manualInputDetected = ($amountOwedInput.val().trim().length > 0);
    });

    function updateTotal() {
      if ($amountOwedInput.val().trim() === '' || manualInputDetected === false) {
        const inputAmount = $numberOfSeatsInput.val();

        if ($numberOfSeatsInput.val().length > 0) {
          const numberOfSeats   = parseInt(inputAmount);
          let   amountOwedCents = numberOfSeats * pricePerSeatCents;

          if (isEncounter && $hasPhysicalInput.val() == 'true') {
            amountOwedCents += pricePhysicalCents;
          }

          formatted = formatter.format(amountOwedCents / integerDivisor);
          formatted = formatted.replace(currency, '').trim();

          $amountOwedInput.val(formatted);
        } else {
          $amountOwedInput.val('');
        }
      }
    }

    updateTotal();
    $numberOfSeatsInput.on('input', updateTotal);

    if (isEncounter) {
      const $totalExcludesPhysicalHint = $('#encounter_order_total_amount_hint');

      function showOrHideHint() {
        if ($hasPhysicalInput.val() == '') {
          $totalExcludesPhysicalHint.show()
        } else {
          $totalExcludesPhysicalHint.hide()
        }
      }

      showOrHideHint();
      $hasPhysicalInput.on('change', function(e) {
        updateTotal();
        showOrHideHint();
      });
    }
  });

  // ===========================================================================
  // Handle addition or removal of optional Encounter Order item rows; this code
  // relies in part on constants defined earlier, for price calculations.
  // ===========================================================================
  //
  init('#encounter_order_item_template', ($encounterOrderItemTemplate) => {
    const $encounterOrderItemsWrapper = $('#encounter_order_items_wrapper');
    const $hasPhysicalInput           = $('#encounter_order_has_physical');
    const $totalExcludesPhysicalHint  = $('#encounter_order_total_amount_hint');
    const $amountOwedInput            = $('#encounter_order_amount_owed');
    const $pricePhysicalCentsHidden   = $('#price_physical_cents');
    const currency                    = $('#price_currency').val();
    const pricePhysicalCents          = parseInt($pricePhysicalCentsHidden.val());

    let   manualInputDetected = false;

    const formatter = new Intl.NumberFormat(
      navigator.language, {
        style:               'currency',
        currency:            currency,
        currencyDisplay:     'code',
        trailingZeroDisplay: 'stripIfInteger',
      }
    );

    const integerDivisor = 10 ** formatter.resolvedOptions().maximumFractionDigits;

    // It's 2026 and JavaScript is still a complete and utter atrocity. A number
    // can be properly formatted into a string via Intl - but not parsed back...
    // We have to use a Float, too. At least precision isn't vital here, since
    // the user can fix the total if need be (sigh).
    //
    function parseFormattedNumber(str, locale = navigator.language) {
      const parts   = new Intl.NumberFormat(locale).formatToParts(11111.1);
      const group   = parts.find(p => p.type === 'group'  )?.value ?? '';
      const decimal = parts.find(p => p.type === 'decimal')?.value ?? '.';

      const normalized = str
        .trim()
        .replaceAll(group, '')
        .replace(decimal, '.');

      return parseFloat(normalized); // (Float, ick)
    }

    // DRY up a few use cases below.
    //
    function rowContaining(htmlElement) {
      return $(htmlElement).closest('.encounter_order_item');
    }

    // Update total price if itemised amounts are entered. There's a fair chunk
    // of close duplication with code earlier, but enough variation to make it
    // mostly worthwhile for sake of keeping this relatively self-contained.
    //
    function updateTotal() {
      if ($amountOwedInput.val().trim() === '' || manualInputDetected === false) {
        let amountOwedCents = 0;

        if ($hasPhysicalInput.val() == 'true') {
          amountOwedCents += pricePhysicalCents;
        }

        $('.encounter_order_item_amount_owed_field').each(function(_index, element) {
          const $row = rowContaining(element);

          if (! $row.is(':hidden')) {
            const itemAmount = $(element).val()?.trim();

            if (itemAmount && itemAmount.length > 0) {
              const itemFloatAmount = parseFormattedNumber(itemAmount);
              const itemCentsAmount = Math.floor(itemFloatAmount * integerDivisor);

              amountOwedCents += itemCentsAmount;
            }
          }
        });

        if (amountOwedCents > 0) {
          formatted = formatter.format(amountOwedCents / integerDivisor);
          formatted = formatted.replace(currency, '').trim();

          $amountOwedInput.val(formatted);
        } else {
          $amountOwedInput.val('');
        }
      }
    }

    function showOrHideHint() {
      if ($hasPhysicalInput.val() == '') {
        $totalExcludesPhysicalHint.show()
      } else {
        $totalExcludesPhysicalHint.hide()
      }
    }

    // Add item rows for Encounter Orders.
    //
    function addRow() {
      const uniqueIdForFormSubmission = "-" + Date.now(); // Negative integer
      const newRowTemplateHtml        = $encounterOrderItemTemplate.html();

      $encounterOrderItemsWrapper.append(
        newRowTemplateHtml.replace(/UNIQUE_ROW_ID/g, uniqueIdForFormSubmission)
      );

      // The DOM updates synchronously here, so the immediately chained-in
      // 'focus' call is safe.
      //
      $('.encounter_order_item:last-child .encounter_order_item_input_field')[0].focus();
    }

    $('#add_encounter_order_item_button').on('click', addRow)

    // Pressing Return adds another item, rather than submitting the form.
    //
    $encounterOrderItemsWrapper.on('keypress', '.encounter_order_item_input_field', function(event) {
      if (event.key === 'Enter') {
        event.preventDefault();

        const $currentRow  = $(this).closest('.encounter_order_item');
        const $allFields   = $currentRow.find('.encounter_order_item_input_field');
        const currentIndex = $allFields.index(this);

        if (currentIndex < $allFields.length - 1) {
          $allFields.eq(currentIndex + 1).focus();
        } else {
          addRow();
        }
      }
    });

    // Remove item rows for new Encounter Orders.
    //
    $encounterOrderItemsWrapper.on('click', '.remove_encounter_order_item_button', function() {
      const $row = rowContaining(this);

      $row.remove();
      updateTotal();
    });

    // Remove item rows when editing Encounter Orders.
    //
    $encounterOrderItemsWrapper.on('click', '.destroy_encounter_order_item_button', function() {
      const $row = rowContaining(this);

      $row.find('input[name*="[_destroy]"]').val('1');
      $row.hide();
      updateTotal();
    });

    updateTotal();
    showOrHideHint();

    $hasPhysicalInput.on('change', function(e) {
      updateTotal();
      showOrHideHint();
    });

    $amountOwedInput.on('input', function(e) {
      manualInputDetected = ($amountOwedInput.val().trim().length > 0);
    });

    $encounterOrderItemsWrapper.on('input', '.encounter_order_item_amount_owed_field', updateTotal);
  });

  // ===========================================================================
  // Handle changes of kind of Encounter Order starting date/time
  // ===========================================================================
  //
  init('[id^="encounter_order_starts_at_kind_"]', ($encounterOrderStartsAtKindRadios) => {
    const $encounterOrderStartsAtKindFixedDateRadio = $('#encounter_order_starts_at_kind_fixed_date');
    const $encounterOrderDateTimeInput              = $('#encounter_order_starts_at');

    function enableOrDisableDateTimeInput() {
      if ($encounterOrderStartsAtKindFixedDateRadio.is(':checked')) {
        $encounterOrderDateTimeInput.prop('disabled', false);
      } else {
        $encounterOrderDateTimeInput.prop('disabled', true);
      }
    }

    enableOrDisableDateTimeInput();
    $encounterOrderStartsAtKindRadios.on('change', enableOrDisableDateTimeInput);
  });

  // ===========================================================================
  // Handle changes of Encounter Order payment method
  // ===========================================================================
  //
  init('#encounter_order_supported_payment_methods_other', ($encounterOrderOtherPaymentMethodCheckbox) => {
    const $encounterOrderOtherPaymentMethodDetailsTextarea = $('#encounter_order_supported_payment_method_other_details');

    function setVisibilities() {
      if ($encounterOrderOtherPaymentMethodCheckbox.is(':checked')) {
        $encounterOrderOtherPaymentMethodDetailsTextarea.show();
      } else {
        $encounterOrderOtherPaymentMethodDetailsTextarea.hide();
      }
    }

    setVisibilities();
    $encounterOrderOtherPaymentMethodCheckbox.change(setVisibilities);
  });


});
