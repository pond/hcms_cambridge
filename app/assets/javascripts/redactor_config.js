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
      spellcheck:      true,
      minHeight:       '450px',
      maxHeight:       '720px',
      toolbarExternal: "#redactor_toolbar",
      plugins:         [
        'alignment',
        'fontcolor',
        'fontsize',
        'table',
        'properties',
        'video',
        'widget'
      ],
      buttons: [
        'format',
        'bold',
        'italic',
        'sup',
        'lists',
        'link',
        'image',
        'html'
      ]
    }
  );
});
