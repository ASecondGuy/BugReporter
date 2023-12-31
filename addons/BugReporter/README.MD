# BugReporter
The BugReporter allows players to send messages using a discord webhook.  
This allows easy and low maintanance feedback from directly inside your game.  
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
send_log=false
send_analytics=true
```

The Reporter Node also gives the option to change the path to the config file, disable auto closing and disable auto clearing for inputs.

# Example usage

![](screenshots/reporter_ui.png) ![](screenshots/message_with_screenshot.png) ![](screenshots/send_screenshot.png)

The playerid depends on the Game name and device id. This allows you to search reports by player but they are still mostly anonymous. You can disable this entirely with `anonymous_players=true`  
If not provided Contact Info will not be displayed.  
You can add or remove as many Categories as you like by editing the OptionButton of the Reporter.  
F2 takes a screenshot (configurable with the input action `screenshot`). The screenshot can be attached to the message.  

# Analytics
Most of the time a screenshot is not enough to figure out what happened in a bugreport.  
To help with that you can allow your players to send analytics with their report.  
The Analytics Report will look something like this.  
```
Report-1692997835-Linux-16-3

root/Example
Example:<Node2D#27682407576>

root/Example/Player
pos: (539, 55), texture: res://icon.png
```
It starts with the Header `Report-Timestamp-OS name`  
Then it lists all nodes in the `analize` group by printing their full node path and the result of their `analize()` (Like root/Example/Player) function if they have one or the result of `_to_string()` (Like root/Example).  
You can put anything in here but you should beware of data protection laws.  

This can be enabled with `send_analytics` in the config file.
## log files
For an easyer to setup variant you can also just send the godot.log file. Again you should beware of data protection laws.

This can be enabled with `send_log` in the config file.

# Customisation
## Message
The looks of the final Message can be entirely customized by changing the `send_report()` function in the `reporter.gd` script and using the `WebhookBuilder` provided with `_http`. 
## UI
The Reporter UI can be easily customized as long as the correct nodes are still provided in the main `Reporter` node.
## More specific questions
More information, questions etc can be freely added by first adding the input nodes (like buttons, LineEdit, etc.) and then adding the information to the message by adding a field, embed or whatever.