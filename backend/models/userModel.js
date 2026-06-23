const mongoose = require('mongoose')
const bcrypt = require('bcrypt')
const validator = require('validator')

const Schema = mongoose.Schema

const userSchema = new Schema({
    username: {
        type: String,
        required: true,
        unique: true
    },
    email: {
        type: String,
        required: true,
        unique: true
    },
    password: {
        type: String,
        required: true
    },
    role: {
        type: String,
        enum: ["parent", "child"],
        default: "parent"
    },
    isVerified: {
        type: Boolean,
        default: false
    },
    parent_id: {
        type: Schema.Types.ObjectId,
        ref: "User",
        default: null
    },
    child_id: [{
        type: Schema.Types.ObjectId,
        ref: "User"
    }]
}, { timestamps: true })

// User SignUp

userSchema.statics.signup = async function (username, email, password) {
    // validation
    if (!username || !email || !password) {
        throw Error('All fields must be filled')
    }

    if (username.length < 3) {
        throw Error('Username must be at least 3 character long')
    }

    if (!validator.isEmail(email)) {
        throw Error('Invalid Email')
    }

    if (!validator.isStrongPassword(password)) {
        throw Error('Password not strong enough')
    }

    const existingUser = await this.findOne({ $or: [{ email }, { username }] })

    if (existingUser) {
        if (existingUser.email == email) {
            throw Error("Email already in use")
        }

        if (existingUser.username == username) {
            throw Error("Username Already Taken")
        }
    }

    const salt = await bcrypt.genSalt(10)
    const hash = await bcrypt.hash(password, salt)

    const user = await this.create({ username, email, password: hash })

    return user
}

userSchema.statics.login = async function (identifier, password) {
    if (!identifier || !password) {
        throw Error("All fields must be filled")
    }

    const user = await this.findOne({
        $or: [{ email: identifier }, { username: identifier }]
    })

    if (!user) {
        throw Error('Invalid Username or email')
    }

    const match = await bcrypt.compare(password, user.password)
    if (!match) {
        throw Error('Incorrect Password')
    }

    return user
}

module.exports = mongoose.model('User', userSchema)