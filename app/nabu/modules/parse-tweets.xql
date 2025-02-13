xquery version "3.1";
(: parse tweets using XQuery 3.1's JSON support
 : see http://www.w3.org/TR/xpath-functions-31/#json
 : sample JSON from https://dev.twitter.com/rest/reference/get/statuses/user_timeline 
 :)

let $json := parse-json('[
    {
        "coordinates": null,
        "favorited": false,
        "truncated": false,
        "created_at": "Wed Aug 29 17:12:58 +0000 2012",
        "id_str": "240859602684612608",
        "entities": {
            "urls": [{
                "expanded_url": "https://dev.twitter.com/blog/twitter-certified-products",
                "url": "https://t.co/MjJ8xAnT",
                "indices": [
                    52,
                    73
                ],
                "display_url": "dev.twitter.com/blog/twitter-c\u2026"
            }],
            "hashtags": [],
            "user_mentions": []
        },
        "in_reply_to_user_id_str": null,
        "contributors": null,
        "text": "Introducing the Twitter Certified Products Program: https://t.co/MjJ8xAnT",
        "retweet_count": 121,
        "in_reply_to_status_id_str": null,
        "id": 240859602684612608,
        "geo": null,
        "retweeted": false,
        "possibly_sensitive": false,
        "in_reply_to_user_id": null,
        "place": null,
        "user": {
            "profile_sidebar_fill_color": "DDEEF6",
            "profile_sidebar_border_color": "C0DEED",
            "profile_background_tile": false,
            "name": "Twitter API",
            "profile_image_url": "http://a0.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png",
            "created_at": "Wed May 23 06:01:13 +0000 2007",
            "location": "San Francisco, CA",
            "follow_request_sent": false,
            "profile_link_color": "0084B4",
            "is_translator": false,
            "id_str": "6253282",
            "entities": {
                "url": {"urls": [{
                    "expanded_url": null,
                    "url": "http://dev.twitter.com",
                    "indices": [
                        0,
                        22
                    ]
                }]},
                "description": {"urls": []}
            },
            "default_profile": true,
            "contributors_enabled": true,
            "favourites_count": 24,
            "url": "http://dev.twitter.com",
            "profile_image_url_https": "https://si0.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png",
            "utc_offset": -28800,
            "id": 6253282,
            "profile_use_background_image": true,
            "listed_count": 10775,
            "profile_text_color": "333333",
            "lang": "en",
            "followers_count": 1212864,
            "protected": false,
            "notifications": null,
            "profile_background_image_url_https": "https://si0.twimg.com/images/themes/theme1/bg.png",
            "profile_background_color": "C0DEED",
            "verified": true,
            "geo_enabled": true,
            "time_zone": "Pacific Time (US Canada)",
            "description": "The Real Twitter API. I tweet about API changes, service issues and happily answer questions about Twitter and our API. Dont get an answer? Its on my website.",
            "default_profile_image": false,
            "profile_background_image_url": "http://a0.twimg.com/images/themes/theme1/bg.png",
            "statuses_count": 3333,
            "friends_count": 31,
            "following": null,
            "show_all_inline_media": false,
            "screen_name": "twitterapi"
        },
        "in_reply_to_screen_name": null,
        "source": "<a href=\"//sites.google.com/site/yorufukurou/\" rel=\"nofollow\">YoruFukurou<\/a>",
        "in_reply_to_status_id": null
    },
    {
        "coordinates": null,
        "favorited": false,
        "truncated": false,
        "created_at": "Sat Aug 25 17:26:51 +0000 2012",
        "id_str": "239413543487819778",
        "entities": {
            "urls": [{
                "expanded_url": "https://dev.twitter.com/issues/485",
                "url": "https://t.co/p5bOzH0k",
                "indices": [
                    97,
                    118
                ],
                "display_url": "dev.twitter.com/issues/485"
            }],
            "hashtags": [],
            "user_mentions": []
        },
        "in_reply_to_user_id_str": null,
        "contributors": null,
        "text": "We are working to resolve issues with application management logging in to the dev portal: https://t.co/p5bOzH0k ^TS",
        "retweet_count": 105,
        "in_reply_to_status_id_str": null,
        "id": 239413543487819778,
        "geo": null,
        "retweeted": false,
        "possibly_sensitive": false,
        "in_reply_to_user_id": null,
        "place": null,
        "user": {
            "profile_sidebar_fill_color": "DDEEF6",
            "profile_sidebar_border_color": "C0DEED",
            "profile_background_tile": false,
            "name": "Twitter API",
            "profile_image_url": "http://a0.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png",
            "created_at": "Wed May 23 06:01:13 +0000 2007",
            "location": "San Francisco, CA",
            "follow_request_sent": false,
            "profile_link_color": "0084B4",
            "is_translator": false,
            "id_str": "6253282",
            "entities": {
                "url": {"urls": [{
                    "expanded_url": null,
                    "url": "http://dev.twitter.com",
                    "indices": [
                        0,
                        22
                    ]
                }]},
                "description": {"urls": []}
            },
            "default_profile": true,
            "contributors_enabled": true,
            "favourites_count": 24,
            "url": "http://dev.twitter.com",
            "profile_image_url_https": "https://si0.twimg.com/profile_images/2284174872/7df3h38zabcvjylnyfe3_normal.png",
            "utc_offset": -28800,
            "id": 6253282,
            "profile_use_background_image": true,
            "listed_count": 10775,
            "profile_text_color": "333333",
            "lang": "en",
            "followers_count": 1212864,
            "protected": false,
            "notifications": null,
            "profile_background_image_url_https": "https://si0.twimg.com/images/themes/theme1/bg.png",
            "profile_background_color": "C0DEED",
            "verified": true,
            "geo_enabled": true,
            "time_zone": "Pacific Time (US Canada)",
            "description": "The Real Twitter API. I tweet about API changes, service issues and happily answer questions about Twitter and our API. Dont get an answer? Its on my website.",
            "default_profile_image": false,
            "profile_background_image_url": "http://a0.twimg.com/images/themes/theme1/bg.png",
            "statuses_count": 3333,
            "friends_count": 31,
            "following": null,
            "show_all_inline_media": false,
            "screen_name": "twitterapi"
        },
        "in_reply_to_screen_name": null,
        "source": "<a href=\"//sites.google.com/site/yorufukurou/\" rel=\"nofollow\">YoruFukurou<\/a>",
        "in_reply_to_status_id": null
    }
]')

let $tweets := $json?*
return
    <tweets>{
        for $tweet in $tweets
        let $id := $tweet?id_str
        let $created := $tweet?created_at
        let $text := $tweet?text
        let $user-id := $tweet?user?screen_name
        let $url := concat('https://twitter.com/', $user-id, '/statuses/', $id)
        return
            <tweet>
                <id>{$id}</id>
                <created>{$created}</created>
                <text>{$text}</text>
                <user-id>{$user-id}</user-id>
                <url>{$url}</url>
            </tweet>
}</tweets>