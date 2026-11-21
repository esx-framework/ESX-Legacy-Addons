# ESX CHAT

`esx_chat` combines the chat interface, roleplay commands, and private messaging into one unified resource.

It includes the following commands:

`/me`, `/do`, `/environment`, `/dice`, `/try`, `/ooc`, `/twt`, `/anontwt`, `/job`, `/pm`, `/msg`, `/report`, and `/help`.

`/msg` is an alias for `/pm` and shares the same sending rate limit. Commands, permissions, and channels can be configured in `config.lua`.

## Installation and Upgrade

1. Back up your custom configurations.
2. Stop and remove `esx_rpchat`, then remove its `ensure` entry from your server configuration.
3. Stop the default FiveM chat resource and replace `ensure chat` with `ensure esx_chat`. Install the complete resource, including all language files.
4. Ensure `esx_chat` starts after `es_extended` and `esx_lib`.

Add the following to your `server.cfg`:

cfg

```cfg
ensure esx_chat
```

This resource provides both `chat` and `esx_rpchat` through FiveM resource replacement.

Only this resource is required for the chat interface. `esx_chat_theme` belongs to the legacy chat system and is no longer needed.

No SQL changes or additional UI builds are required for this integration.

## Migrated Configuration Options

- `EnableESXIdentity` and `OnlyFirstname` control the displayed player name.
- `ProximityDistance` limits roleplay messages to nearby players within the same instance. The sender also receives their own message.
- `ProximityMaxLength` limits proximity actions based on Unicode character count.
- `CommandCooldowns` preserves individual cooldowns for roleplay chat commands.
- `RateLimit` continues to provide global rate limiting across all messages.
- Visibility preferences retain the existing `esx_chat:displayMode` key.

## Security and Validation

- The server validates message recipients and permissions.
- Private messages are delivered exclusively to the sender and intended recipient.
- Anonymous tweets hide the author's identity from the public while preserving it in existing moderation logs.
- Client-provided names cannot override the player's actual server-side identity.
- `_chat:messageEntered` passes through server-side validation and `chatMessage` cancellation.

## Compatibility

The message area reserves a default height of `calc(var(--u) * 470)` in `web/style.css`, even when there are few messages or the chat is empty.

- Scaling and width remain responsive to screen resolution.
- Height is reduced only when available screen space is insufficient.
- Suggestions support scrolling.
- Chat boxes do not use shadows or background blur.

### Preserved Events and Features

The following existing events and features remain supported:

- `chat:addMessage`
- `chatMessage`
- Chat suggestions
- Chat templates
- `chat:clear`
- Both signatures of `esx_rpchat:sendProximityMessage`

### Export Compatibility

The following exports are supported and routed to the same interface as their `esx_chat` equivalents:

- Client and server `chat:addMessage`
- Client `chat:addSuggestion`

## Migration Notes

Customizations from older configurations must be manually transferred to `config.lua`.

The resource does not read configuration files from the previously removed resource folders.