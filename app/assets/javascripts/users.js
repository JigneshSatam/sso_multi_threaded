// # Place all the behaviors and hooks related to the matching controller here.
// # All this logic will automatically be available in application.js.
// # You can use CoffeeScript in this file: http://coffeescript.org/

$(document).ready( function(){
  $(".log-in").click(function(){
    $(".signIn").addClass("active-dx");
    $(".signUp").addClass("inactive-sx");
    $(".signUp").removeClass("active-sx");
    $(".signIn").removeClass("inactive-dx");
  });

  $(".back").click(function(){
    $(".signUp").addClass("active-sx");
    $(".signIn").addClass("inactive-dx");
    $(".signIn").removeClass("active-dx");
    $(".signUp").removeClass("inactive-sx");
  });
});
