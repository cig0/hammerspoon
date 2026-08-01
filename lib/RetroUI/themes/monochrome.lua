return {
    id = "monochrome", label = "Monochrome",
    dialog = {
        backgroundColor = {white = 0, alpha = 1}, bodyTextColor = {white = 1, alpha = 1},
        noticeTextColor = {white = 1, alpha = 1}, titleTextColor = {white = 1, alpha = 1}, hotkeyTextColor = {white = 1, alpha = 1}
    },
    frame = {borderColor = {white = 1, alpha = 1}, style = "single", titleAlignment = "center"},
    button = {
        normal = {faceColor = {white = 1, alpha = 1}, textColor = {white = 0, alpha = 1}, hotkeyColor = {white = 0, alpha = 1}},
        hovered = {faceColor = {white = 0.8, alpha = 1}, textColor = {white = 0, alpha = 1}, hotkeyColor = {white = 0, alpha = 1}},
        focused = {faceColor = {white = 0.7, alpha = 1}, textColor = {white = 0, alpha = 1}, hotkeyColor = {white = 0, alpha = 1}},
        pressed = {faceColor = {white = 0.5, alpha = 1}, textColor = {white = 1, alpha = 1}, hotkeyColor = {white = 1, alpha = 1}},
        disabled = {faceColor = {white = 0.3, alpha = 1}, textColor = {white = 0.5, alpha = 1}, hotkeyColor = {white = 0.5, alpha = 1}},
        shadowColor = {white = 0, alpha = 1}
    }
}
