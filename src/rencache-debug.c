static FILE* debug_log_file = NULL;
static int frame_counter = 0;

void rencache_debug_init(const char* log_path) {
    debug_log_file = fopen(log_path, "w");
    if (!debug_log_file) {
        fprintf(stderr, "Failed to open debug log file: %s\n", log_path);
        return;
    }
    frame_counter = 0;
}

void rencache_debug_close(void) {
    if (debug_log_file) {
        fclose(debug_log_file);
        debug_log_file = NULL;
    }
}

static void log_timestamp(void) {
    time_t now;
    char timestamp[26];
    time(&now);
#ifdef _WIN32
    ctime_s(timestamp, sizeof(timestamp), &now);
#else
    ctime_r(&now, timestamp);
#endif
    timestamp[24] = '\0';  // Remove newline
    fprintf(debug_log_file, "[%s] ", timestamp);
}

void rencache_debug_log_frame(RenCache* cache) {
    if (!debug_log_file) return;

    log_timestamp();
    fprintf(debug_log_file, "Frame %d Begin\n", ++frame_counter);
    
    // Log surface dimensions
    fprintf(debug_log_file, "Surface: %dx%d\n", 
            cache->surface_rect.width, 
            cache->surface_rect.height);

    // Log all commands for this frame
    Command *cmd = NULL;
    int cmd_counter = 0;
    
    fprintf(debug_log_file, "Commands:\n");
    while (next_command(cache, &cmd)) {
        cmd_counter++;
        
        switch (cmd->type) {
            case SET_CLIP: {
                SetClipCommand *ccmd = (SetClipCommand*)&cmd->command;
                fprintf(debug_log_file, "  %d: SET_CLIP {x:%d, y:%d, w:%d, h:%d}\n",
                        cmd_counter,
                        ccmd->rect.x, ccmd->rect.y,
                        ccmd->rect.width, ccmd->rect.height);
                break;
            }
            
            case DRAW_RECT: {
                DrawRectCommand *rcmd = (DrawRectCommand*)&cmd->command;
                fprintf(debug_log_file, "  %d: DRAW_RECT {x:%d, y:%d, w:%d, h:%d} "
                        "color{r:%d, g:%d, b:%d, a:%d}\n",
                        cmd_counter,
                        rcmd->rect.x, rcmd->rect.y,
                        rcmd->rect.width, rcmd->rect.height,
                        rcmd->color.r, rcmd->color.g,
                        rcmd->color.b, rcmd->color.a);
                break;
            }
            
            case DRAW_TEXT: {
                DrawTextCommand *tcmd = (DrawTextCommand*)&cmd->command;
                fprintf(debug_log_file, "  %d: DRAW_TEXT {x:%.1f, y:%d, w:%d, h:%d} "
                        "color{r:%d, g:%d, b:%d, a:%d} text:\"%.*s\"\n",
                        cmd_counter,
                        tcmd->text_x, tcmd->rect.y,
                        tcmd->rect.width, tcmd->rect.height,
                        tcmd->color.r, tcmd->color.g,
                        tcmd->color.b, tcmd->color.a,
                        (int)tcmd->len, tcmd->text);
                break;
            }
        }
    }
    
    // Log dirty rectangles
    fprintf(debug_log_file, "Dirty Rectangles (%d):\n", cache->rect_count);
    for (int i = 0; i < cache->rect_count; i++) {
        RenRect *r = &cache->rect_buf[i];
        fprintf(debug_log_file, "  %d: {x:%d, y:%d, w:%d, h:%d}\n",
                i + 1, r->x, r->y, r->width, r->height);
    }
    
    fprintf(debug_log_file, "Frame %d End\n\n", frame_counter);
    fflush(debug_log_file);
}
