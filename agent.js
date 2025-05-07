/** @format */

module.exports = agent => {
  // You can also send messages to the App Worker through the messenger object
  // But you need to wait for the App Worker to start successfully before sending, otherwise it may be lost
  agent.messenger.on('egg-ready', () => {
    //   const data = { ... };
    agent.messenger.sendToApp('netstat_action', {});
  });
};
