---
layout: page
title: Projects
permalink: /projects/
---

## My Write-ups

<ul>
  {% for project in site.projects %}
    <li>
      <a href="{{ project.url | relative_url }}">
        <strong>{{ project.title }}</strong>
      </a> - {{ project.description }}
    </li>
  {% endfor %}
</ul>
