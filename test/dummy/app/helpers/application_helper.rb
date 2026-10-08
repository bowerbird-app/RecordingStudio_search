module ApplicationHelper
  def dummy_page_nav(title:, back_url: nil, back_label: "Home")
    recording_studio_page_nav(
      title: title,
      page_nav_back_url: back_url,
      page_nav_back_label: back_label
    )

    recording_studio_page_nav_right do
      concat recording_studio_root_switch_dropdown(style: :ghost, size: :md)
      concat render(
        FlatPack::Button::Component.new(
          text: "Sign out",
          style: :ghost,
          size: :md,
          href: main_app.destroy_user_session_path,
          data: { turbo_method: :delete }
        )
      )
    end
  end

  def dummy_search_demo_buttons
    render FlatPack::OverflowRow::Component.new(gap: :sm) do
      safe_join(
        [
          render(FlatPack::Button::Component.new(
            text: "Just people",
            href: people_path,
            style: :secondary,
            size: :md
          )),
          render(FlatPack::Button::Component.new(
            text: "As you type",
            href: instant_people_path,
            style: :secondary,
            size: :md
          )),
          render(FlatPack::Button::Component.new(
            text: "In a group",
            href: groups_path,
            style: :secondary,
            size: :md
          )),
          render(FlatPack::Button::Component.new(
            text: "Title first",
            href: title_first_path,
            style: :secondary,
            size: :md
          ))
        ]
      )
    end
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
