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

# Example usage

![](screenshots/reporter_ui.png) ![](screenshots/discord_message.png)

The playerid depends on the Game name and device id. This allows you to search reports by player but they are still mostly anonymous. You can disable this entirely with `anonymous_players=false`  
If not provided Contact Info will not be displayed.  
You can add or remove as many Categories as you like by editing the OptionButton of the Reporter.  
Screenshots are not currently working even thou the UI supports it and the code is mostly there too. Mostly. (Sorry!)