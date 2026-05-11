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
		Puzzle = {
			TotalStages = 3,
			Stages = {
				{
					Size = 6,
					Pairs = {
						{ Id = 1, Color = "#FF6B6B", Endpoints = { { 1, 1 }, { 1, 6 } } },
						{ Id = 2, Color = "#4D96FF", Endpoints = { { 2, 1 }, { 5, 1 } } },
						{ Id = 3, Color = "#6BCB77", Endpoints = { { 6, 1 }, { 6, 6 } } },
						{ Id = 4, Color = "#FFD93D", Endpoints = { { 2, 6 }, { 5, 6 } } },
						{ Id = 5, Color = "#B980F0", Endpoints = { { 3, 2 }, { 4, 5 } } },
					},
				},
				{
					Size = 8,
					Pairs = {
						{ Id = 1, Color = "#FF6B6B", Endpoints = { { 1, 1 }, { 1, 8 } } },
						{ Id = 2, Color = "#4D96FF", Endpoints = { { 2, 1 }, { 7, 1 } } },
						{ Id = 3, Color = "#6BCB77", Endpoints = { { 8, 1 }, { 8, 8 } } },
						{ Id = 4, Color = "#FFD93D", Endpoints = { { 2, 8 }, { 7, 8 } } },
						{ Id = 5, Color = "#B980F0", Endpoints = { { 3, 2 }, { 6, 2 } } },
						{ Id = 6, Color = "#52D1DC", Endpoints = { { 3, 7 }, { 6, 7 } } },
						{ Id = 7, Color = "#FF9F1C", Endpoints = { { 4, 3 }, { 5, 6 } } },
					},
				},
				{
					Size = 10,
					Pairs = {
						{ Id = 1, Color = "#FF6B6B", Endpoints = { { 1, 1 }, { 1, 10 } } },
						{ Id = 2, Color = "#4D96FF", Endpoints = { { 2, 1 }, { 9, 1 } } },
						{ Id = 3, Color = "#6BCB77", Endpoints = { { 10, 1 }, { 10, 10 } } },
						{ Id = 4, Color = "#FFD93D", Endpoints = { { 2, 10 }, { 9, 10 } } },
						{ Id = 5, Color = "#B980F0", Endpoints = { { 3, 2 }, { 8, 2 } } },
						{ Id = 6, Color = "#52D1DC", Endpoints = { { 3, 9 }, { 8, 9 } } },
						{ Id = 7, Color = "#FF9F1C", Endpoints = { { 4, 3 }, { 4, 8 } } },
						{ Id = 8, Color = "#FF85A1", Endpoints = { { 7, 3 }, { 7, 8 } } },
						{ Id = 9, Color = "#F1F1F1", Endpoints = { { 5, 4 }, { 6, 7 } } },
					},
				},
			},
		},
		Code = {
			TotalStages = 3,
			Letters = { "I", "J", "K", "L" },
			Stages = {
				{
					Lines = {
						{ Html = '<override code="acid-balance">', SequenceLength = 4 },
					},
				},
				{
					Lines = {
						{ Html = '<override code="sensor-lattice">', SequenceLength = 4 },
						{ Html = '<commit checksum="ion-grid" />', SequenceLength = 4 },
					},
				},
				{
					Lines = {
						{ Html = '<override code="cryo-thaw">', SequenceLength = 4 },
						{ Html = '<inject channel="aux-pump">', SequenceLength = 4 },
						{ Html = '<seal status="manual" />', SequenceLength = 4 },
					},
				},
			},
		},
	},
}

return GameplayConfig