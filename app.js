/** @format */

class AppBootHook {
  constructor(app) {
    this.app = app;
  }
  async serverDidReady() {
    this.app.serverDidReady();
  }
  async beforeClose() {
    this.app.beforeClose();
    // Please place your app.beforeClose code here
  }
}

module.exports = AppBootHook;
