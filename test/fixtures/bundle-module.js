// Generated by purs bundle 0.13.5
var PS = {};
(function(exports) {
  "use strict";

  exports.log = function (s) {
    return function () {
      console.log(s);
      return {};
    };
  };
})(PS["Effect.Console"] = PS["Effect.Console"] || {});
(function($PS) {
  // Generated by purs version 0.13.5
  "use strict";
  $PS["Effect.Console"] = $PS["Effect.Console"] || {};
  var exports = $PS["Effect.Console"];
  var $foreign = $PS["Effect.Console"];
  exports["log"] = $foreign.log;
})(PS);
(function($PS) {
  // Generated by purs version 0.13.5
  "use strict";
  $PS["Main"] = $PS["Main"] || {};
  var exports = $PS["Main"];
  var Effect_Console = $PS["Effect.Console"];                
  var main = Effect_Console.log("\ud83c\udf5d");
  exports["main"] = main;
})(PS);
module.exports = PS["Main"];
