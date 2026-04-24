$(document).ready(function() {

  // ===========================================================================
  // Copy buttons
  // ===========================================================================
  //
  const copyFromDataButtons = $('button.copy_from_data[data-text]');

  if (copyFromDataButtons.length > 0) {
    copyFromDataButtons.on('click', function(e) {
      const targetButton = $(this);

      text = targetButton.data('text');
      navigator.clipboard.writeText(text);

      icon = targetButton.find('i.fa');
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
  // "Manage booking" for Encounter Orders - toggling physical item
  // ===========================================================================
  //
  const encounterOrderPhysicalCheckbox = $('#encounter_order_has_physical');
  const encounterOrderIdHidden         = $('#id_for_changes');
  const encounterOrderTokenHidden      = $('#token_for_changes');

  if (
    encounterOrderPhysicalCheckbox.length > 0 &&
    encounterOrderIdHidden.length         > 0 &&
    encounterOrderTokenHidden.length      > 0
  ) {
    const invoiceButton    = $('#encounter_order_invoice_button');
    const id               = encounterOrderIdHidden.val();
    const token            = encounterOrderTokenHidden.val();
    let   callIsInProgress = false;

    function disableElts() {
      encounterOrderPhysicalCheckbox.prop('disabled', true);

      invoiceButton.addClass('disabled')
      invoiceButton.attr('aria-disabled', 'true')
      invoiceButton.on('click.guard', e => e.preventDefault());
    }

    function enableElts() {
      encounterOrderPhysicalCheckbox.prop('disabled', false);

      invoiceButton.removeClass('disabled')
      invoiceButton.removeAttr('aria-disabled')
      invoiceButton.off('click.guard');
    }

    $(encounterOrderPhysicalCheckbox).on('change', function () {
      const checked = encounterOrderPhysicalCheckbox.prop('checked');

      disableElts()
      $('.js-physical-warning').remove()

      $.ajax({
        url:     `/manage_encounter/${id}/${token}`,
        method:  'PATCH',
        headers: { 'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content') },
        data:    { state_ajax: 'toggle', has_physical: (checked ? '1' : '0') },

        success() {
          enableElts();
        },

        error() {
          encounterOrderPhysicalCheckbox.prop('checked', !checked);
          enableElts();
          $('<div class="field_error_messages js-physical-warning">Could not save change — please try again.</p>')
            .insertAfter(encounterOrderPhysicalCheckbox);
        },
      });
    });
  }
});
