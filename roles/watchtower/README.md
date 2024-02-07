# telerect-t-watchtower
Watchtower container for Telerec't

* [github](https://github.com/containrrr/watchtower) 
* [docs](https://containrrr.dev/watchtower/)


To enable watching a container add the label:   
`com.centurylinklabs.watchtower.enable="true"`

To manually trigger a scan run, where `http_token` is whatever you set in `watchtower.http_token` (default=`abracadabra`)
```
curl -H "Authorization: Bearer {{ http_token }}" https://watchtower.example.com/v1/update
```

## Service config
  * `version`: Which version of [containrrr/watchtower](https://hub.docker.com/r/containrrr/watchtower) to use (default = latest)
  * `poll_interval`: Poll interval (in seconds). This value controls how frequently watchtower will poll for new images. See [docs](https://containrrr.dev/watchtower/arguments/#poll_interval)
  * `http_token`: Api token for sending http requests to watchtower (see [docs](https://containrrr.dev/watchtower/http-api-mode/)). HTTP API mode is only activated if this token is non-empty. 
  * `telegram_bot_token`
  * `telegram_channel_id`
