$(document).on('ready page:load', function() {

  var csrf_token = $('meta[name=csrf-token]').attr('content');
  var csrf_param = $('meta[name=csrf-param]').attr('content');
  var params;

  if (csrf_param !== undefined && csrf_token !== undefined)
  {
      params = csrf_param + "=" + encodeURIComponent(csrf_token);
  }

  $R(
    '.custom_redactor',
    {
      path:            "/assets/redactor3-rails",
      fileUpload:      "/redactor3_rails/files?"  + params,
      imageUpload:     "/redactor3_rails/images?" + params,
      imageResizable:  true,
      imagePosition:   true,
      toolbarExternal: "#redactor_toolbar",
      plugins:         [
        'alignment',
        'fontcolor',
        'fontsize',
        'video'
      ],

      buttons: [
        'format',
        'bold',
        'italic',
        'unorderedlist',
        'orderedlist',
        'outdent',
        'indent',
        'image',
        'link',
        'html'
      ]
    }
  );

});
