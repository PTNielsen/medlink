class UserPolicy < ApplicationPolicy
  def update?
    super || record == user
  end

  def respond?
    # A headless policy is asking if we can respond to _some_ user
    admin? || \
    (user.pcmo? && record == :user) || \
    country_pcmo?
  end

  def report?
    admin?
  end

  def inactivate?
    admin? && record != user
  end
end
