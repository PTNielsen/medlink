FactoryGirl.define do
  factory :user do
    sequence(:email)   {|n| "user#{n}@example.com"}
    password 'password'
    role     'pcv'
    time_zone 'Alaska'
    country { FactoryGirl.create(:country) }
    sequence(:first_name) { |n| "user#{n}"}
    sequence(:last_name)  { |n| "user#{n}last"}
    sequence(:pcv_id)     { |n| n}
    sequence(:location)   { |n| "location#{n}"}
    confirmed_at { rand(12..8760).hours.ago }

    factory :pcv

    factory :admin do
      role 'admin'
    end

    factory :pcmo do
      role 'pcmo'
    end
  end
end
