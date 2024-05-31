config.bind("J", "tab-prev")
config.bind("K", "tab-next")
config.bind("x", "tab-close")
config.bind("X", "undo")
config.bind("d", "scroll-page 0 0.25")
config.bind("D", "nop")
config.bind("u", "scroll-page 0 -0.25")
config.bind("p", "open -t {clipboard}")

config.bind("<Num+2>", "tab-prev")
config.bind("<Num+3>", "tab-next")
config.bind("<Num+5>", "tab-close")
config.bind("<Num+6>", "undo")

config.bind("<Num+9>", "open -t {primary}")

c.content.notifications.enabled = False
c.content.tls.certificate_errors = "ask-block-thirdparty"

# config.bind("<Num+7>", "yank")
# config.bind("<Num+0>", "insert-text {clipboard}")

c.url.searchengines = {
    "DEFAULT": "https://www.google.com/search?q={}",
    "ddg": "https://www.duckduckgo.com/?q={}"
}
c.url.start_pages = [
    "https://en.wikipedia.org"
]

c.downloads.remove_finished = 3000
c.downloads.position = "bottom"
c.downloads.location.directory = "~/dld"
c.downloads.location.prompt = True
c.tabs.select_on_remove = "prev"
config.load_autoconfig(True)
