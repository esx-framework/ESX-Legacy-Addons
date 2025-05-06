export const Nui = {
  async send(event, data = {}) {
    try {
      const resp = await fetch(`https://${GetParentResourceName()}/${event}`, {
        method: "post",
        headers: {
          "Content-Type": "application/json; charset=UTF-8",
        },
        body: JSON.stringify(data),
      });

      return await resp.json();
    } catch (error) {
      throw Error(`Failed to fetch NUI callback ${event}! (${error})`);
    }
  },

  emulate(type, data = null) {
    window.dispatchEvent(
      new MessageEvent("message", {
        data: { type, data },
      }),
    );
  },
};
