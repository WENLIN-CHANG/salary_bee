module ApplicationHelper
  def flash_css_class(type)
    case type.to_s
    when "alert", "error"
      "brutalist-error"
    when "notice", "success"
      "brutalist-success"
    when "warning"
      "brutalist-warning"
    else
      "brutalist-info"
    end
  end
end
