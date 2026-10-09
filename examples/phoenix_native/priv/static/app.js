(() => {
  const csrfToken = document.querySelector("meta[name='csrf-token']")?.content;
  if (window.LiveView && window.Phoenix) {
    const liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
      params: { _csrf_token: csrfToken }
    });
    liveSocket.connect();
    window.liveSocket = liveSocket;
  }

  window.fixtureChannel = () => {
    const socket = new Phoenix.Socket("/socket", { params: {} });
    socket.connect();
    const channel = socket.channel("room:test", {});
    channel.join();
    return { socket, channel };
  };

  window.fixtureEvents = () => new EventSource("/events");
})();
