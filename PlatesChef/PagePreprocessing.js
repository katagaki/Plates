var ExtensionPreprocessingJS = new (function () {
  this.run = function (completionFunction) {
    var scripts = Array.prototype.slice.call(
      document.querySelectorAll('script[type="application/ld+json"]'), 0, 10
    ).map(function (script) { return script.textContent.slice(0, 500000); });
    completionFunction({ url: location.href, jsonLD: scripts });
  };
})();
