# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_bossmenu — Jobs

  @kora_bossmenu @checklist @checklist:kora_bossmenu:open-bossmenu-command @cat:jobs
  Scenario: Boss menu (/openbossmenu)
    """
    Checklist test: As a job boss run /openbossmenu: console with Overview, Employees, Applicants, Questions; non-boss refused.
    """
    When I manually: make sure my job is one where I have a boss grade
    And I run the command "/openbossmenu"
    Then the "qbbossmenu:management" app opens
    And I confirm: the console shows Overview, Employees, Applicants and Questions sections
    When I manually: switch to a non-boss grade of a job and run /openbossmenu again
    Then I should see a notification containing "You cannot open this boss menu."
    And I confirm: the boss menu console does not open

  @kora_bossmenu @checklist @checklist:kora_bossmenu:open-bossmenu-gang @cat:jobs
  Scenario: Gang menu (/openbossmenu gang)
    """
    Checklist test: As gang boss run /openbossmenu gang: roster has ranks, no pay, Kick to remove.
    """
    When I manually: make sure I am a gang boss of a gang
    And I run the command "/openbossmenu gang"
    Then the "qbbossmenu:management" app opens
    And I confirm: the gang roster shows member ranks and no pay
    When I manually: click Kick on a gang member
    Then I confirm: the member is removed from the gang roster

  @kora_bossmenu @checklist @checklist:kora_bossmenu:boss-target-location @cat:jobs
  Scenario: Boss menu at configured location
    """
    Checklist test: Police: go to boss point (447.9,-973.4,30.7) and use the target; Ballas at (322.2,-1005.7,29.3).
    """
    Given my job is "police"
    And I am at 447.9, -973.4, 30.7
    When I manually: make sure my police grade is a boss grade, then use the target at the boss point
    Then the "qbbossmenu:management" app opens
    When I manually: set my gang to ballas at a boss grade, go to 322.2, -1005.7, 29.3 and use the target
    Then I confirm: the gang boss menu opens

  @kora_bossmenu @checklist @checklist:kora_bossmenu:set-rank @cat:jobs
  Scenario: Set employee rank
    """
    Checklist test: Employees tab: Set rank on an employee with a grade; job grade changes (online or offline).
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: open the Employees tab, click Set rank on an employee with a grade, choose a new grade and confirm
    Then I confirm: the employee's job grade changes to the chosen grade
    When I manually: repeat Set rank on an offline employee
    Then I confirm: the offline employee's job grade changes too

  @kora_bossmenu @checklist @checklist:kora_bossmenu:give-bonus @cat:jobs
  Scenario: Give bonus
    """
    Checklist test: Give bonus to an employee; debited from society account (kora_banking); insufficient funds refused.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: open the Employees tab and give a bonus to an employee
    Then I confirm: the bonus amount is debited from the society account in kora_banking
    When I manually: give a bonus larger than the society account balance
    Then I confirm: the bonus is refused and the society balance is unchanged

  @kora_bossmenu @checklist @checklist:kora_bossmenu:fire-employee @cat:jobs
  Scenario: Fire employee
    """
    Checklist test: Fire an employee; they lose the job and confirmation applies.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: open the Employees tab, click Fire on an employee and confirm
    Then I confirm: the fired employee loses the job
    And I confirm: the confirmation is applied and shown

  @kora_bossmenu @checklist @checklist:kora_bossmenu:boss-stash @cat:jobs
  Scenario: Open boss stash
    """
    Checklist test: Click Open boss stash: console closes and 80-slot stash opens.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: click Open boss stash
    Then I should see a notification containing "Boss stash opened."
    And the "stash" inventory opens
    And I confirm: the boss menu console closes
    And I confirm: the stash has 80 slots

  @kora_bossmenu @checklist @checklist:kora_bossmenu:job-apply @cat:jobs
  Scenario: Apply for a job (/jobapply <job>)
    """
    Checklist test: Run /jobapply police (or at apply points): form generated from the job questions; submit.
    """
    When I run the command "/jobapply police"
    Then I confirm: a form titled "Apply: police" opens, generated from the police job questions
    When I manually: fill in the form and submit it
    Then I should see a notification containing "Your application was submitted."

  @kora_bossmenu @checklist @checklist:kora_bossmenu:review-applicants @cat:jobs
  Scenario: Review applicants (hire/deny)
    """
    Checklist test: Applicants tab: read answers, Hire or Deny; hired player gets the job.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: open the Applicants tab and read an applicant's answers
    Then I confirm: the applicant's answers are shown
    When I manually: click Hire on an applicant
    Then I confirm: the hired player gets the job
    When I manually: click Deny on another applicant
    Then I confirm: the denied applicant is removed from the list

  @kora_bossmenu @checklist @checklist:kora_bossmenu:manage-questions @cat:jobs
  Scenario: Manage application questions
    """
    Checklist test: Questions tab: add, edit (short/long/number/yes-no) and remove questions, up to 20.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    When I manually: open the Questions tab and add a question
    Then I confirm: the new question appears in the list
    When I manually: edit questions using each type: short, long, number and yes-no
    Then I confirm: each edited question is saved with its type
    When I manually: remove a question
    Then I confirm: the question is removed from the list
    When I manually: try to add questions beyond 20
    Then I confirm: no more than 20 questions can be added

  @kora_bossmenu @checklist @checklist:kora_bossmenu:activity-log @cat:jobs
  Scenario: Activity timeline
    """
    Checklist test: Overview shows recent boss actions (last 100 logs).
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    And I confirm: the Overview shows the recent boss actions timeline, up to the last 100 logs

  @kora_bossmenu @checklist @checklist:kora_bossmenu:business-balance @cat:jobs
  Scenario: Business balance display
    """
    Checklist test: Overview shows the society balance, owned by kora_banking.
    """
    When I manually: as a boss of a job, run /openbossmenu
    Then the "qbbossmenu:management" app opens
    And I confirm: the Overview shows the society balance matching the kora_banking society account
