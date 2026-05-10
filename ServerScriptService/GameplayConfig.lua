local GameplayConfig = {
	Roles = {
		Tagger = "Tagger",
		Survivor = "Survivor",
	},
	Tag = {
		MaxDistance = 5,
		NoTagBackTime = 3,
	},
	Invisibility = {
		Duration = 3,
		Cooldown = 20,
	},
	Shove = {
		MaxDistance = 6,
		Cooldown = 2,
		RagdollDuration = 2,
		Distance = 10,
		TravelTime = 0.2,
	},
	Movement = {
		DefaultWalkSpeed = 16,
		MaxSprintDuration = 3,
		NormalRecoveryDuration = 5,
		ExhaustedRecoveryDuration = 10,
		SprintSpeedMultiplier = 1.5,
		CrouchSpeedMultiplier = 0.55,
		JumpReductionMultiplier = 0.9,
		SlideSpeedMultiplier = 2.1,
		SlideBurstSpeedMultiplier = 2.6,
		SlideDuration = 1.5,
		SlideBurstDuration = 0.18,
		SlideSprintEnergyPenalty = 0.5,
	},
	TaskMinigame = {
		TotalSegments = 3,
		SuccessStep = 1,
		FailureStep = 1,
		GreenWidthMax = 0.24,
		GreenWidthMin = 0.12,
		MarkerWidthScale = 0.08,
		SidePaddingScale = 0.08,
		SwingSpeed = 0.9,
		Spam = {
			TotalStages = 3,
			GoalStartScale = 0.88,
			GoalWidthScale = 0.12,
			FillPerTap = 0.08,
			BaseDecayPerSecond = 0.12,
			StageDecayIncrease = 0.12,
		},
	},
}

return GameplayConfig