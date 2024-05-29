# BugReporter
The BugReporter allows players to send messages using a discord webhook.  
Webhooks can be easily abused for anonymous automated spam. That makes this a bad solution for games with many players.

# Config
This is an example config with all needed values. Only the url is needed. game_name will default to "unnamed_game" if not specified.

```
[webhook]

url="https://discord.com/api/webhooks/<webhook.id>/<webhook.token>"
game_name="BugReporter"
tts=false
color=15258703
anonymous_players=false
```

The Reporter Node also gives the option to change the path to the config file, disable auto closing and disable auto clearing for inputs.

<span style="color:red">**WARNING:** The webhook url can be used to read all messages send with the webhook.  
Do NOT use the url directly if you allow sending any non anonymous information.  
Using the url for anonymous messages is still highly discouraged.  
See Proxy section for save usage.
</span>

# Example usage

![](screenshots/reporter_ui.png) ![](screenshots/message_with_screenshot.png) ![](screenshots/send_screenshot.png)

The playerid depends on the Game name and device id. This allows you to search reports by player but they are still mostly anonymous. You can disable this entirely with `anonymous_players=false`  
If not provided Contact Info will not be displayed.  
You can add or remove as many Categories as you like by editing the OptionButton of the Reporter.  
F2 takes a screenshot (configurable with the input action `screenshot`). The screenshot can be attached to the message.


# Proxy
To prevent data leaks and potential data privacy lawsuits you need to setup a proxy.
A Proxy will relay any messages to discord while ignoring unwanted actions (reading, deleting etc.).  

The recomended way is to use a cloudflare worker with this code. Then put the proxy url in the webhook.cfg instead of the webhook url.
```js
export default {
  async fetch(request) {
    const destinationURL = "webhook url";
    if (request.method === "POST") {
      const mod = await fetch(destinationURL, request);
      return new Response(null, {status: mod.status});
    }
    return new Response("Only POST is allowed", { status: 403 });
  },
};
```

Make sure the webhook url is only in this code to make sure nobody malicius can get a hold of it.  
If you want to implement a content filter or spam prevention this would be a good place to do it.

