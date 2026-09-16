module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )
  end

  def page_cover_path(page)
    slug = page.title.to_s.parameterize
    candidate = Rails.public_path.join("covers", "#{slug}.svg")
    return "/covers/#{slug}.svg" if candidate.exist?

    "/covers/page.svg"
  end

  def page_published_on(page)
    page.created_at.to_date.to_fs(:long)
  end

  def weighted_hit_label(page, query)
    needle = query.to_s.downcase
    in_title = page.title.to_s.downcase.include?(needle)
    in_body = page.body.to_s.downcase.include?(needle)

    if in_title && in_body
      "Title and body"
    elsif in_title
      "Title"
    elsif in_body
      "Body"
    else
      "Close match"
    end
  end
end
