class BlogUser < ActiveRecord::Base
  has_many :user_posts, :class_name => 'UserPost'
  has_many :blog_posts, :through => :user_posts
end

class UserPost < ActiveRecord::Base
  belongs_to :blog_users, :foreign_key => 'user_id', :class_name => 'BlogUser'
  belongs_to :blog_posts, :foreign_key => 'post_id', :class_name => 'BlogPost'
end

class BlogPost < ActiveRecord::Base
  has_many :user_posts, :class_name => 'UserPost'
  has_many :blog_users, :through => :user_posts
end

