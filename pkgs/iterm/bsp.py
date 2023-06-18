import iterm2 as it


async def get_app(conn: it.Connection) -> it.App:
    app = await it.async_get_app(conn)
    assert app is not None, "app was None"
    return app


def find_parent(splitter: it.Splitter, session: it.Session) -> it.Splitter:
    for child in splitter.children:
        if isinstance(child, it.Splitter):
            res = find_parent(child, session)
            if res is not None:
                return res

        elif child is session:
            return splitter

    raise AssertionError("Session not found in tree")


async def main(conn):
    app = await get_app(conn)

    @it.RPC
    async def bsp_split(
        session_id: str = it.Reference("id") # type: ignore
    ):
        session = app.get_session_by_id(session_id)
        assert session is not None

        tab = session.tab
        assert tab is not None

        # Vertical state undefined for a single session under root. Handle this
        # case specially
        vertical = True
        if len(tab.root.children) > 1:
            vertical = not find_parent(tab.root, session).vertical

        await session.async_split_pane(vertical)

    await bsp_split.async_register(conn)

it.run_forever(main)
