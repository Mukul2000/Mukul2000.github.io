---
layout: page
title: Posts
permalink: /posts/
---

## My Write-ups

<ul>
  {% for post in site.posts_dir %}
    <li>
      <a href="{{ post.url | relative_url }}">
        <strong>{{ post.title }}</strong>
      </a> - {{ post.description }}
    </li>
  {% endfor %}
</ul>
