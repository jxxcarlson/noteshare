$(document).ready(function(){


  function update_rendered_content(data, status) {

    $('#rendered_content').html(data);

    reloadMathJax();

  }


  function udpate_document() {

    var element = document.getElementById('document-updated-text');
    var source_text = element.value;

    var element2 = document.getElementById('document-document-id');
    var id = element2.value;

    $.post( 'http://localhost:2300/editor/json_update/' + id, { source: source_text}, update_rendered_content );
  }

  $('#update_source_button').click(udpate_document);



});
