//= require jquery
//= require shared

$(document).ready(function() {

  // ===========================================================================
  // Unobtrusive on-click confirmation prompt via data attribute
  // ===========================================================================
  //
  const buttonsWithConfirmsSelector = $('button[data-confirm], input[type="submit"][data-confirm]');

  buttonsWithConfirmsSelector.on('click', function(e) {
    let warning = $(this).data('confirm');

    if (!confirm(warning)) {
      e.preventDefault();
      e.stopPropagation();
      return false;
    }
  });

  // ===========================================================================
  // A small amount of dynamic behaviour for encounter order self-service pages
  // ===========================================================================
  //
  const addressRequiredCentsHidden = $('#address_required_threshold_cents');

  if (addressRequiredCentsHidden.length > 0) {
    const encounterOrderHomeAddressSection = $('#encounter_order_address_entry');
    const addPhysicalCheckbox              = $('#encounter_order_has_physical');
    const amountForSeatsHidden             = $('#amount_for_seats_cents');
    const pricePhysicalCentsHidden         = $('#price_physical_cents');
    const amountForSeatsCents              = parseInt(amountForSeatsHidden.val());
    const pricePhysicalCents               = parseInt(pricePhysicalCentsHidden.val());
    const addressRequiredCents             = parseInt(addressRequiredCentsHidden.val());
    const addressRequiredAtThreshold       = !isNaN(addressRequiredCents);

    function setElementVisibility(e) {
      let showAddress       = false;
      let overallTotalCents = amountForSeatsCents;

      if (addPhysicalCheckbox.is(':checked')) {
        overallTotalCents += pricePhysicalCents;
      }

      if (addressRequiredAtThreshold && overallTotalCents >= addressRequiredCents) {
        showAddress = true;
      }

      if (showAddress) {
        encounterOrderHomeAddressSection.show(e == null ? null : 'fast');
      } else {
        encounterOrderHomeAddressSection.hide(e == null ? null : 'fast');
      }
    }

    setElementVisibility(null);
    addPhysicalCheckbox.on('change', setElementVisibility);
  }
});
