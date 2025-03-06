function setupInputElement(element) {
   if (!element.hasAttribute("data-gmod-initialized")) {
      element.setAttribute("data-gmod-initialized", "true");

      element.addEventListener("click", function () {
         if (!this.id) {
            this.id = "gmod_input_" + Math.random().toString(36).substr(2, 9);
         }

         this.focus();
         this.select();
         gmod.inputLock(this.id);
      });
   }
}

function setupEditableElement(element) {
   if (!element.hasAttribute("data-gmod-initialized")) {
      element.setAttribute("data-gmod-initialized", "true");

      element.addEventListener("click", function () {
         if (!this.id) {
            this.id =
               "gmod_editable_" + Math.random().toString(36).substr(2, 9);
         }

         this.focus();
         if (window.getSelection && document.createRange) {
            const range = document.createRange();
            range.selectNodeContents(this);
            const selection = window.getSelection();
            selection.removeAllRanges();
            selection.addRange(range);
         }
         gmod.inputLock(this.id);
      });
   }
}

function initializeExistingElements() {
   document.querySelectorAll("input, textarea").forEach(setupInputElement);
   document
      .querySelectorAll("[contentEditable=true]")
      .forEach(setupEditableElement);
}

function setupMutationObserver() {
   const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
         if (mutation.addedNodes && mutation.addedNodes.length > 0) {
            mutation.addedNodes.forEach((node) => {
               if (node.nodeType === Node.ELEMENT_NODE) {
                  if (node.matches("input, textarea")) {
                     setupInputElement(node);
                  }

                  if (node.getAttribute("contentEditable") === "true") {
                     setupEditableElement(node);
                  }

                  if (node.querySelectorAll) {
                     node
                        .querySelectorAll("input, textarea")
                        .forEach(setupInputElement);
                     node
                        .querySelectorAll("[contentEditable=true]")
                        .forEach(setupEditableElement);
                  }
               }
            });
         }
      });
   });

   observer.observe(document.body, {
      childList: true,
      subtree: true,
   });

   return observer;
}

initializeExistingElements();
setupMutationObserver();

console.log("[WBUI] Injected.");
