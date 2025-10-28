// ~/.finicky.js
export default {
  defaultBrowser: "Comet",
  // rewrite: [
  //   {
  //     // Redirect all x.com urls to use xcancel.com
  //     match: "x.com/*",
  //     url: (url) => {
  //       url.host = "xcancel.com";
  //       return url;
  //     },
  //   },
  // ],
  handlers: [
    {
      // Open all bsky.app urls in Firefox
      match: "*",
      browser: "Comet",
      profile: "Profile 1"
    },
  ],
};

