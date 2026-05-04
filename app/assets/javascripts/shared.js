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
  // Copy buttons
  // ===========================================================================
  //
  init('button.copy_from_data[data-text]', ($copyFromDataButtons) => {
    $copyFromDataButtons.on('click', function(e) {
      const $targetButton = $(this);
      const $icon         = $targetButton.find('i.fa');
      const text          = $targetButton.data('text');

      navigator.clipboard.writeText(text);
      $icon.removeClass('fa-copy').addClass('fa-check');

      window.setTimeout(
        function() {
          $icon.removeClass('fa-check').addClass('fa-copy');
        },
        2000
      );
    });
  });

  // ===========================================================================
  // "Manage booking" for Encounter Orders - toggling physical item
  // ===========================================================================
  //
  init('#encounter_order_has_physical', ($encounterOrderPhysicalCheckbox) => {
    const $encounterOrderIdHidden                   = $('#id_for_changes');
    const $encounterOrderTokenHidden                = $('#token_for_changes');
    const $encounterOrderPeopleAndPriceRowContainer = $('#people_and_price_row');

    // NOTE EARLY EXIT.
    //
    if (! $encounterOrderIdHidden.length || ! $encounterOrderTokenHidden.length) return;

    const $invoiceButton = $('#encounter_order_invoice_button');
    const id             = $encounterOrderIdHidden.val();
    const token          = $encounterOrderTokenHidden.val();

    function disableElts() {
      $encounterOrderPhysicalCheckbox.prop('disabled', true);

      $invoiceButton.addClass('disabled');
      $invoiceButton.attr('aria-disabled', 'true');
      $invoiceButton.on('click.guard', e => e.preventDefault());
    }

    function enableElts() {
      $encounterOrderPhysicalCheckbox.prop('disabled', false);

      $invoiceButton.removeClass('disabled');
      $invoiceButton.removeAttr('aria-disabled');
      $invoiceButton.off('click.guard');
    }

    $encounterOrderPhysicalCheckbox.on('change', function () {
      const checked = $encounterOrderPhysicalCheckbox.prop('checked');

      disableElts();
      $('.dynamic').remove()
      $encounterOrderPhysicalCheckbox
        .closest('div.field')
        .find('.field_with_errors')
        .contents()
        .unwrap();

      $.ajax({
        url:     `/manage_encounter/${id}/${token}`,
        method:  'PATCH',
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
        data:    { state_ajax: 'toggle', has_physical: (checked ? '1' : '0') },

        success(html) {
          $encounterOrderPeopleAndPriceRowContainer.html(html);
          enableElts();
        },

        error() {
          $encounterOrderPhysicalCheckbox.prop('checked', !checked);
          enableElts();

          const $field = $encounterOrderPhysicalCheckbox.closest('div.field');

          $field.wrapInner('<div class="field_with_errors">');
          $('<div class="field_error_messages dynamic">Could not save that change - please try again.</div>')
            .insertAfter($field);
        },
      });
    });
  });
});
