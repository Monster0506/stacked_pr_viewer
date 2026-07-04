class StackDetector
  def self.call(repo_config)
    new(repo_config).call
  end

  def initialize(repo_config)
    @repo_config = repo_config
  end

  def call
    prs = @repo_config.pull_requests.where(state: "open").to_a
    head_branch_to_pr = prs.index_by(&:head_branch)

    prs.each do |pr|
      next if pr.stack_membership&.manual_override

      root = find_root(pr, head_branch_to_pr)
      chain = build_chain(root, prs)

      stack = root.stack_membership&.stack || @repo_config.stacks.create!

      chain.each_with_index do |member_pr, index|
        membership = stack.stack_memberships.find_or_initialize_by(pull_request: member_pr)
        next if membership.manual_override

        membership.update!(position: index)
      end
    end
  end

  private

  def find_root(pr, head_branch_to_pr)
    seen = Set.new
    current = pr
    while (parent = head_branch_to_pr[current.base_branch]) && seen.add?(current.id)
      current = parent
    end
    current
  end

  def build_chain(root, all_prs)
    head_to_children = all_prs.group_by(&:base_branch)
    chain = []
    seen = Set.new
    current = root
    while current && seen.add?(current.id)
      chain << current
      current = head_to_children[current.head_branch]&.first
    end
    chain
  end
end
