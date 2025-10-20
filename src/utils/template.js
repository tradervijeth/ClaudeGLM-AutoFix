"use strict";

function renderTemplate(template, variables = {}) {
  return template.replace(/{{\s*([a-zA-Z0-9_]+)\s*}}/g, (match, key) => {
    if (Object.prototype.hasOwnProperty.call(variables, key)) {
      const value = variables[key];
      if (value === null || value === undefined) {
        return "";
      }
      return typeof value === "string" ? value : JSON.stringify(value, null, 2);
    }
    return "";
  });
}

module.exports = {
  renderTemplate
};
