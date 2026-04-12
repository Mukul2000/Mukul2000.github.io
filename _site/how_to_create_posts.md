

### 1. Create the Markdown File
Add a new `.md` file to the `_posts_dir/` directory. You can name it anything (e.g., `my-new-post.md`).

### 2. Add Front Matter
At the very top of your new file, you **must** include the following "Front Matter" block so Jekyll knows how to display it:

```markdown
---
layout: page
title: "Your Post Title Here"
description: "A short summary of what this post is about."
---

Your content goes here... you can use **Markdown**!
```

### 3. Verification (How it works)
*   **Automatic Listing:** The "Posts" page (`/posts/`) is already set up to loop through every file in the `_posts_dir/` folder. Your new post will appear there automatically.
*   **Automatic URL:** Based on your current configuration, your post will be accessible at: `yourdomain.com/post/filename-without-extension` (e.g., `/post/my-new-post`).

### Summary of where things are:
*   **Content:** Always goes in `_posts_dir/`.
*   **Navigation:** If you ever want to change the "Posts" tab name again, edit `_data/navigation.yml`.
*   **Page Layout:** The look of the list of posts is controlled by `Posts.md`.
*   **Configuration:** The URL structure is defined in `_config.yml` under `collections -> posts_dir`.

**Note:** If you are running the site locally, remember that changes to `_config.yml` require you to stop and restart the `bundle exec jekyll serve` command, but adding new posts in `_posts_dir/` will usually update instantly!
