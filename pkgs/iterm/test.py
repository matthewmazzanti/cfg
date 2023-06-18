import iterm2 as it

async def get_app(conn: it.Connection) -> it.App:
    app = await it.async_get_app(conn)
    if app is None:
        raise Exception("App was None")

    return app


async def get_tab_session(app: it.App) -> tuple[it.Tab, it.Session]:
    win = app.current_window
    if win is None:
        raise Exception("Current window was None")

    tab = win.current_tab
    if tab is None:
        raise Exception("Current tab was None")

    session = tab.current_session
    if session is None:
        raise Exception("Current session was None")

    return tab, session


def find_parent(splitter: it.Splitter, session: it.Session) -> it.Splitter:
    for child in splitter.children:
        if isinstance(child, it.Splitter):
            res = find_parent(child, session)
            if res is not None:
                return res

        elif child is session:
            return splitter

    raise Exception()


async def main(conn):
    app = await get_app(conn)
    tab, session = await get_tab_session(app)

    # Vertical state undefined for a single session under root. Handle this
    # case specially
    vertical = True
    if len(tab.root.children) > 1:
        vertical = not find_parent(tab.root, session).vertical

    await session.async_split_pane(vertical)


it.run_until_complete(main)
