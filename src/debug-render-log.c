#include <stdio.h>
#include <time.h>
#include <sys/stat.h>
#include "debug-render-log.h"

extern int save_surface_to_png(SDL_Surface* surface, const char* filename);

static char log_directory[256];
static FILE* current_frame_file = NULL;
static int frame_count = 0;
static int frames_to_skip = 10; // Save every 10th frame
static int surface_count = 0;  // Counter for surfaces within current frame

static void write_html_header(FILE* f) {
    fprintf(f, "<!DOCTYPE html>\n<html>\n<head>\n");
    fprintf(f, "<title>Frame %d Debug View</title>\n", frame_count);
    fprintf(f, "<style>\n");
    fprintf(f, "body { font-family: Arial, sans-serif; margin: 20px; background: #f0f0f0; }\n");
    fprintf(f, ".event { margin: 5px 0; padding: 5px; background: #f8f8f8; border-left: 3px solid #ddd; }\n");
    fprintf(f, ".surface { border-left-color: #4CAF50; }\n");
    fprintf(f, ".zerosurf { border-left-color: #AF504C; }\n");
    fprintf(f, ".rect { border-left-color: #2196F3; }\n");
    fprintf(f, ".frame { background: white; padding: 15px; border-radius: 5px; margin: 10px 0; }\n");
    fprintf(f, ".surface-image { max-width: 100%%; border: 1px solid #ddd; margin: 5px 0; }\n");
    fprintf(f, "</style>\n</head>\n<body>\n");
    fprintf(f, "<div class=\"frame\">\n");
    fprintf(f, "<h2>Frame %d</h2>\n", frame_count);
}

static void write_html_footer(FILE* f) {
    fprintf(f, "</div>\n");
    if (frame_count > 1) {
        fprintf(f, "<p><a href=\"frame_%d.html\">Previous Frame</a> | ", frame_count - 1);
    }
    fprintf(f, "<a href=\"frame_%d.html\">Next Frame</a></p>\n", frame_count + 1);
    fprintf(f, "</body>\n</html>\n");
}

void debug_render_log_init(const char* log_dir) {
    struct stat st = {0};
    snprintf(log_directory, sizeof(log_directory), "%s", log_dir);

    if (stat(log_dir, &st) == -1) {
        if (mkdir(log_dir, 0700) != 0) {
            fprintf(stderr, "Failed to create debug log directory: %s\n", log_dir);
            return;
        }
    }
    debug_render_log_frame();
}

void debug_render_log_surface(RenSurface *rs, int x, int y) {
    if (!current_frame_file) return;

    surface_count++;

    int w, h;
    rensurf_get_size(rs, &w, &h);
    if (w > 0 && h > 0) {
        fprintf(current_frame_file, "<div class=\"event surface\">");
        fprintf(current_frame_file, "Surface %d at (%d,%d) of size (%d,%d)", surface_count, x, y, w, h);
        fprintf(current_frame_file, "</div>\n");
        fprintf(current_frame_file, "<img src=\"%d.png\" class=\"surface-image\">\n", surface_count);

        char png_path[512];
        snprintf(png_path, sizeof(png_path), "%s/%d.png", log_directory, surface_count);
        save_surface_to_png(rs->surface, png_path);
    } else {
        fprintf(current_frame_file, "<div class=\"event zerosurf\">");
        fprintf(current_frame_file, "Zero size Surface %d at (%d,%d) of size (%d,%d)", surface_count, x, y, w, h);
        fprintf(current_frame_file, "</div>\n");
    }
    fflush(current_frame_file);
}

void debug_render_log_rect(SDL_Rect *r, SDL_Color color) {
    if (!current_frame_file) return;

    fprintf(current_frame_file, "<div class=\"event rect\">");
    fprintf(current_frame_file, "Rectangle at (%d,%d,%d,%d) color(%d,%d,%d,%d)",
            r->x, r->y, r->w, r->h, color.r, color.g, color.b, color.a);
    fprintf(current_frame_file, "</div>\n");
    fflush(current_frame_file);
}

void debug_render_log_frame(void) {
    if (current_frame_file) {
        write_html_footer(current_frame_file);
        fclose(current_frame_file);
        current_frame_file = NULL;
    }

    surface_count = 0;  // Reset surface counter for new frame

    if (frame_count % frames_to_skip == 0) {
        // Create new frame file
        char frame_path[512];
        snprintf(frame_path, sizeof(frame_path), "%s/frame_%d.html", log_directory, frame_count);

        current_frame_file = fopen(frame_path, "w");
        if (!current_frame_file) {
            fprintf(stderr, "Failed to open frame file: %s\n", frame_path);
            return;
        }
        write_html_header(current_frame_file);
    }

    frame_count++;
}

